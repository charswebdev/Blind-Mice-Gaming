# Icon files

Batch 4 of the data pack. Approved on 2026-10-29. Phase 1 packed the TGAs listed below.

WoW does not draw a PNG or a JPG as an addon icon. The file the client loads is an uncompressed 32-bit TGA. BMG Event Tracker already hit this: a PNG icon does not appear. The TGA used there is 64 by 64, with the same header shape as the other Blind Mice Gaming addon icons.

The JPG files in [`reference/`](reference/) stay the art reference. A TGA is made only for a picture Charlotte has approved, and only when a coding phase needs that file.

## Packed for phase 1

Phase 1 converted the approved JPGs into uncompressed 32-bit TGA files in `BMGAM/Media`. The addon list icon is 64 by 64, matching the other Blind Mice Gaming icons. The JPG files in [`reference/`](reference/) stay the art reference.

| Picture | Reference | Use |
|---------|-----------|-----|
| Addon icon | [addon-icon.jpg](reference/addon-icon.jpg) | The minimap button and the icon in WoW’s addon list. The list groups the addon under Blind Mice Gaming. Same picture for both |
| Close | [close-button.jpg](reference/close-button.jpg) | The title-bar close button |
| Overview tab | [tab-overview.jpg](reference/tab-overview.jpg) | First tab button. Approved 2026-10-29 |
| Gear tab | [tab-gear.jpg](reference/tab-gear.jpg) | Tab button |
| Bags tab | [tab-bags.jpg](reference/tab-bags.jpg) | Tab button |
| Bank tab | [tab-bank.jpg](reference/tab-bank.jpg) | Tab button |
| Professions tab | [tab-professions.jpg](reference/tab-professions.jpg) | Tab button |
| Reputation tab | [tab-reputation.jpg](reference/tab-reputation.jpg) | Tab button |
| Mail tab | [tab-mail.jpg](reference/tab-mail.jpg) | Tab button |
| Currency tab | [tab-currency.jpg](reference/tab-currency.jpg) | Tab button. Approved 2026-10-29 |
| Vault tab | [tab-vault.jpg](reference/tab-vault.jpg) | Midnight tab button. Approved 2026-10-29 |
| Auction tab | [tab-auction.jpg](reference/tab-auction.jpg) | Gold gavel. Approved 2026-10-29 |
| Quests tab | [tab-quests.jpg](reference/tab-quests.jpg) | Rolled scroll. Approved 2026-10-29 |
| Achievements tab | [tab-achievements.jpg](reference/tab-achievements.jpg) | Gold trophy. Approved 2026-10-29 |
| Collections tab | [tab-collections.jpg](reference/tab-collections.jpg) | Glass display case. Approved 2026-10-29 |
| Settings | [settings-button.jpg](reference/settings-button.jpg) | Title-bar button, left of Close. Approved 2026-10-29 |
| Forget character | [trash-button.jpg](reference/trash-button.jpg) | Far right of the selected character’s name line. Approved 2026-10-29 |

## Never packed

These come from the WoW client. The addon points `SetTexture` at the client file. It does not ship a copy.

| Use | Source |
|-----|--------|
| Class icon on the character card | The client class-icon set |
| Race portrait in the right header | The client race portrait for that race and sex |
| Item icon | The item’s own icon |
| Gold, silver, and copper coins | The client coin textures |
| Talent icon on Overview | The client’s icon for that talent |
