# Token Meter Release Workflow

Tag-driven release pipeline for Token Meter. The local release command prepares the repository and pushes a version tag. GitHub Actions performs the build, GitHub Release upload, and Homebrew tap update after the tag is pushed.

## Usage

`$release [version]`

- `version` is optional. Example: `0.3.0`
- If omitted, bump the patch version from `Resources/Info.plist`

## Steps

Execute these steps sequentially. Stop and report the failure if any step fails.

### 1. Determine Version

- Read the current version from `Resources/Info.plist` using `CFBundleShortVersionString`.
- If the user provided a version, use it.
- Otherwise:
  - Find the latest git tag.
  - Check unreleased commits with `git log <latest-tag>..HEAD --oneline`.
  - Bump the patch version even if there are no unreleased commits, because the user explicitly requested a release.
- Confirm with the user before proceeding:
  - `Releasing v{version} — proceed?`

### 2. Update Info.plist

- Update `CFBundleShortVersionString` in `Resources/Info.plist` to the target version.

### 3. Commit and Push token-meter

```bash
git add Resources/Info.plist
git commit -m "chore: bump version to {version}"
git push origin main
```

### 4. Create Git Tag

Build the changelog from commits since the previous tag using `git log <prev-tag>..HEAD --oneline`.

Format:

```markdown
## <Summary title>

- <bullet describing a user-facing change>

**Full Changelog**: https://github.com/younghyundev/token-meter/compare/<prev-tag>...v{version}
```

Then create and push the tag:

```bash
git tag v{version}
git push origin v{version}
```

After the tag is pushed, GitHub Actions will:

- build the app on GitHub-hosted macOS
- create `TokenMeter-{version}.zip`
- create the GitHub Release
- update `younghyundev/homebrew-tap`

### 5. Report

Report:

- pushed tag
- GitHub Actions workflow status
- token-meter release URL
- `brew update && brew upgrade token-meter`
