<?php
/**
 * Copy to config.php on the server. Do not commit config.php.
 * Fill these from the same MySQL account you use in phpMyAdmin.
 */
return [
    'db_host' => 'localhost',
    'db_name' => 'YOUR_DATABASE_NAME',
    'db_user' => 'YOUR_DATABASE_USER',
    'db_pass' => 'YOUR_DATABASE_PASSWORD',
    'pepper' => 'CHANGE_THIS_TO_A_LONG_RANDOM_STRING',
    'max_body' => 65536,
    'max_shares_per_token' => 20,
    'max_posts_per_ip_hour' => 30,
];
