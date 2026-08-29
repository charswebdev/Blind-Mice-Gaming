<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$tables = [
    'retail' => 'lptm_retail',
    'classic' => 'lptm_classic',
    'classic-era' => 'lptm_classic_era',
    'anniversary' => 'lptm_anniversary',
];

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
    fail(500, 'Community host is not configured.');
}

$config = require $configPath;
$flavor = strtolower(trim((string) ($_GET['flavor'] ?? '')));
if (!isset($tables[$flavor])) {
    fail(400, 'Unknown community flavor.');
}
$table = $tables[$flavor];

try {
    $pdo = new PDO(
        sprintf(
            'mysql:host=%s;dbname=%s;charset=utf8mb4',
            $config['db_host'],
            $config['db_name']
        ),
        $config['db_user'],
        $config['db_pass'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
} catch (PDOException $error) {
    fail(500, 'Could not reach the community database.');
}
if (!isset($pdo)) {
    fail(500, 'Could not reach the community database.');
}

$method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
if ($method === 'GET') {
    echo json_encode(list_builds($pdo, $table), JSON_UNESCAPED_UNICODE);
    exit;
}
if ($method !== 'POST') {
    fail(405, 'Use GET or POST.');
}

rate_limit($config);
$payload = read_json((int) ($config['max_body'] ?? 65536));
$action = strtolower(trim((string) ($payload['action'] ?? '')));
if ($action === 'share') {
    echo json_encode(share_build($pdo, $table, $payload, $config), JSON_UNESCAPED_UNICODE);
    exit;
}
if ($action === 'unshare') {
    echo json_encode(unshare_build($pdo, $table, $payload, $config), JSON_UNESCAPED_UNICODE);
    exit;
}
fail(400, 'Unknown action.');

function list_builds(PDO $pdo, string $table): array
{
    $updated = $pdo->query("SELECT MAX(updated) AS updated FROM `{$table}`")->fetchColumn();
    $rows = $pdo->query("SELECT * FROM `{$table}` ORDER BY updated DESC")->fetchAll();
    $builds = [];
    foreach ($rows as $row) {
        $builds[] = public_build($row);
    }
    return [
        'updated' => $updated ? to_iso((string) $updated) : '',
        'builds' => $builds,
    ];
}

function share_build(PDO $pdo, string $table, array $payload, array $config): array
{
    $token = owner_token($payload);
    $hash = owner_hash($token, (string) $config['pepper']);
    $build = $payload['build'] ?? null;
    if (!is_array($build)) {
        fail(400, 'Share needs a build.');
    }
    $row = normalize_build($build);
    $limit = (int) ($config['max_shares_per_token'] ?? 20);
    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM `{$table}` WHERE owner_hash = ? AND id <> ?");
    $countStmt->execute([$hash, $row['id']]);
    if ((int) $countStmt->fetchColumn() >= $limit) {
        fail(429, 'Too many community shares for this player.');
    }

    $found = $pdo->prepare("SELECT owner_hash FROM `{$table}` WHERE id = ?");
    $found->execute([$row['id']]);
    $existing = $found->fetchColumn();
    if ($existing !== false && !hash_equals((string) $existing, $hash)) {
        fail(403, 'That community listing belongs to another player.');
    }

    $sql = "INSERT INTO `{$table}` (
            id, name, content, build_type, class_id, class_name, spec_id, spec_name,
            hero_id, hero_name, patch, created, updated, trees, talent_string, owner_hash
        ) VALUES (
            :id, :name, :content, :build_type, :class_id, :class_name, :spec_id, :spec_name,
            :hero_id, :hero_name, :patch, :created, :updated, :trees, :talent_string, :owner_hash
        ) ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            content = VALUES(content),
            build_type = VALUES(build_type),
            class_id = VALUES(class_id),
            class_name = VALUES(class_name),
            spec_id = VALUES(spec_id),
            spec_name = VALUES(spec_name),
            hero_id = VALUES(hero_id),
            hero_name = VALUES(hero_name),
            patch = VALUES(patch),
            updated = VALUES(updated),
            trees = VALUES(trees),
            talent_string = VALUES(talent_string)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($row + ['owner_hash' => $hash]);
    return ['ok' => true, 'id' => $row['id']];
}

function unshare_build(PDO $pdo, string $table, array $payload, array $config): array
{
    $token = owner_token($payload);
    $hash = owner_hash($token, (string) $config['pepper']);
    $id = strtolower(trim((string) ($payload['id'] ?? '')));
    if (!is_uuid($id)) {
        fail(400, 'Unshare needs a community id.');
    }
    $stmt = $pdo->prepare("DELETE FROM `{$table}` WHERE id = ? AND owner_hash = ?");
    $stmt->execute([$id, $hash]);
    if ($stmt->rowCount() < 1) {
        fail(404, 'That community listing was not found for this player.');
    }
    return ['ok' => true, 'id' => $id];
}

function public_build(array $row): array
{
    $trees = json_decode((string) $row['trees'], true);
    if (!is_array($trees)) {
        $trees = [];
    }
    return [
        'id' => $row['id'],
        'name' => $row['name'],
        'content' => $row['content'],
        'type' => $row['build_type'],
        'class_id' => $row['class_id'],
        'class_name' => $row['class_name'],
        'spec_id' => $row['spec_id'],
        'spec_name' => $row['spec_name'],
        'hero_id' => $row['hero_id'],
        'hero_name' => $row['hero_name'],
        'patch' => $row['patch'],
        'created' => to_iso((string) $row['created']),
        'updated' => to_iso((string) $row['updated']),
        'trees' => $trees,
        'string' => $row['talent_string'],
    ];
}

function normalize_build(array $build): array
{
    $id = strtolower(trim((string) ($build['id'] ?? '')));
    if (!is_uuid($id)) {
        fail(400, 'Build id is not valid.');
    }
    $name = trim((string) ($build['name'] ?? 'Untitled'));
    $name = substr($name, 0, 200);
    if ($name === '') {
        $name = 'Untitled';
    }
    $trees = $build['trees'] ?? [];
    if (is_string($trees)) {
        $decoded = json_decode($trees, true);
        $trees = is_array($decoded) ? $decoded : [];
    }
    if (!is_array($trees)) {
        fail(400, 'Build trees are not valid.');
    }
    $now = gmdate('Y-m-d H:i:s');
    return [
        'id' => $id,
        'name' => $name,
        'content' => substr(trim((string) ($build['content'] ?? '')), 0, 120),
        'build_type' => substr(trim((string) ($build['type'] ?? '')), 0, 120),
        'class_id' => substr(trim((string) ($build['class_id'] ?? '')), 0, 32),
        'class_name' => substr(trim((string) ($build['class_name'] ?? '')), 0, 64),
        'spec_id' => substr(trim((string) ($build['spec_id'] ?? '')), 0, 32),
        'spec_name' => substr(trim((string) ($build['spec_name'] ?? '')), 0, 64),
        'hero_id' => substr(trim((string) ($build['hero_id'] ?? '')), 0, 64),
        'hero_name' => substr(trim((string) ($build['hero_name'] ?? '')), 0, 64),
        'patch' => substr(trim((string) ($build['patch'] ?? '')), 0, 16),
        'created' => to_sql_datetime((string) ($build['created'] ?? ''), $now),
        'updated' => $now,
        'trees' => json_encode($trees, JSON_UNESCAPED_UNICODE),
        'talent_string' => substr((string) ($build['string'] ?? ''), 0, 4000),
    ];
}

function owner_token(array $payload): string
{
    $token = trim((string) ($payload['owner_token'] ?? ''));
    if (strlen($token) < 16) {
        fail(400, 'Share needs an owner token.');
    }
    return $token;
}

function owner_hash(string $token, string $pepper): string
{
    if ($pepper === '' || $pepper === 'CHANGE_THIS_TO_A_LONG_RANDOM_STRING') {
        fail(500, 'Community host is not configured.');
    }
    return hash('sha256', $token . $pepper);
}

function read_json(int $maxBody): array
{
    $raw = file_get_contents('php://input') ?: '';
    if (strlen($raw) > $maxBody) {
        fail(413, 'That share is too large.');
    }
    $payload = json_decode($raw, true);
    if (!is_array($payload)) {
        fail(400, 'Body must be JSON.');
    }
    return $payload;
}

function rate_limit(array $config): void
{
    $max = (int) ($config['max_posts_per_ip_hour'] ?? 30);
    $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0');
    $file = sys_get_temp_dir() . '/lptm-rate-' . hash('sha256', $ip) . '.json';
    $now = time();
    $hits = [];
    if (is_file($file)) {
        $decoded = json_decode((string) file_get_contents($file), true);
        if (is_array($decoded)) {
            $hits = $decoded;
        }
    }
    $hits = array_values(array_filter($hits, static fn($stamp) => is_int($stamp) && $stamp > $now - 3600));
    if (count($hits) >= $max) {
        fail(429, 'Too many community writes. Try again later.');
    }
    $hits[] = $now;
    @file_put_contents($file, json_encode($hits), LOCK_EX);
}

function is_uuid(string $value): bool
{
    return (bool) preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $value);
}

function to_iso(string $sqlDate): string
{
    $stamp = strtotime($sqlDate . ' UTC');
    if ($stamp === false) {
        return $sqlDate;
    }
    return gmdate('Y-m-d\TH:i:s', $stamp);
}

function to_sql_datetime(string $value, string $fallback): string
{
    $value = trim($value);
    if ($value === '') {
        return $fallback;
    }
    $stamp = strtotime($value);
    if ($stamp === false) {
        return $fallback;
    }
    return gmdate('Y-m-d H:i:s', $stamp);
}

function fail(int $code, string $message): never
{
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}
