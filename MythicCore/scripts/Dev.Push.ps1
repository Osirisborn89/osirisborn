param([string]$Message = "checkpoint")
$repo = Join-Path $env:USERPROFILE 'Osirisborn'

git -C $repo add -A
if (-not (git -C $repo status --porcelain)) { Write-Host "Nothing to commit."; exit 0 }
git -C $repo commit -m $Message

# current branch
$current = (git -C $repo rev-parse --abbrev-ref HEAD).Trim()

# does an upstream exist?
$null = git -C $repo rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
if ($LASTEXITCODE -ne 0) {
  git -C $repo push --set-upstream origin $current
} else {
  git -C $repo push
}
