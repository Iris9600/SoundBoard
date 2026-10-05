# Solar contribution identity

`Solar` is the display name for assistant-authored contributions. The owner supplied GitHub account `Solar-owo` and commit email `338115045+Solar-owo@users.noreply.github.com`. The repository owner's Git identity remains unchanged.

## Account and commit attribution

Use the supplied identity only for assistant-authored commits after the owner approves the changes. The GitHub account associated with the commit email controls contributor attribution and the avatar displayed on GitHub. Never use an invented email or an unrelated account.

Use per-command Git settings for both author and committer:

```sh
git -c user.name=Solar -c user.email=338115045+Solar-owo@users.noreply.github.com commit -m "Describe the approved change"
```

This command is documentation, not permission to commit pending changes. Push credentials are separate from commit attribution; using Solar's author identity does not log Git into Solar's account or grant repository access.

The working branch is `D-Time`. Prepare and verify changes for review in VS Code, wait for the owner's explicit confirmation, then commit and push only the approved work to `origin/D-Time`. The owner reviews and merges unless they explicitly delegate review and merge for that work. See the repository root `AGENTS.md` for the complete workflow.

## Avatar

`avatar.png` is the prepared Yuuki Asuna avatar. Upload it through the `Solar-owo` account's profile settings. A repository image does not update a GitHub profile automatically.

Generated using the built-in image generation tool, with this final prompt:

```text
Use case: stylized-concept
Asset type: square GitHub contributor avatar
Primary request: Yuuki Asuna from Sword Art Online as the avatar for a contributor named Solar.
Subject: recognizable Asuna with long chestnut hair, amber-brown eyes, gentle confident smile, and her white-and-red Knights of the Blood uniform.
Style: polished original anime illustration, clean linework and soft cel shading.
Composition: centered head-and-shoulders portrait, square 1024 by 1024, face large and readable at small avatar sizes, generous safe margin for circular cropping.
Background: simple soft light background.
Constraints: one character, no text, no logo, no watermark.
```
