param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [string]$Tag
)

git status
git add .

git commit -m "$Message"

if ($Tag) {
    git tag $Tag
    git push origin $Tag
}

git push
