<#
.SYNOPSIS
    Syncs blog posts from Obsidian vault to Hugo blog.

.DESCRIPTION
    Scans Obsidian blog folder for posts with status: ready or status: scheduled,
    transforms front matter to Hugo/PaperMod format, and copies to blog repo.

.PARAMETER DryRun
    Preview what would be synced without making changes.

.PARAMETER Push
    Automatically commit and push changes to GitHub after sync.

.PARAMETER Force
    Overwrite existing posts even if they haven't changed.

.EXAMPLE
    .\sync-obsidian-posts.ps1 -DryRun
    Preview what posts would be synced.

.EXAMPLE
    .\sync-obsidian-posts.ps1 -Push
    Sync posts and push to GitHub.
#>

param(
    [switch]$DryRun,
    [switch]$Push,
    [switch]$Force
)

# Configuration
$ObsidianPath = "C:\Users\herms\OneDrive\Obsidian Vault\Hermes's Life Knowledge Base\07 HomeLab Things\Homelab Blog Posts"
$BlogPath = "C:\Users\herms\Side Projects\Clustered-Thoughts"
$PostsPath = Join-Path $BlogPath "content\posts"

# Series to Category mapping
$SeriesMapping = @{
    "Origins" = @("Homelab", "Origins")
    "Foundation Layer" = @("Homelab", "Infrastructure")
    "Containerization Deep-Dives" = @("Homelab", "Containers")
    "Observability & Monitoring" = @("Homelab", "Monitoring")
    "Automation & Bots" = @("Homelab", "Automation")
    "Advanced Topics" = @("Homelab", "Advanced")
    "Lessons Learned" = @("Homelab", "Lessons")
}

function Write-Status {
    param([string]$Message, [string]$Type = "Info")

    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "DryRun" { "Cyan" }
        default { "White" }
    }

    $prefix = switch ($Type) {
        "Success" { "[OK]" }
        "Warning" { "[WARN]" }
        "Error" { "[ERROR]" }
        "DryRun" { "[DRY RUN]" }
        default { "[INFO]" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Parse-FrontMatter {
    param([string]$Content)

    $frontMatter = @{}
    $body = ""

    if ($Content -match "(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)$") {
        $yamlContent = $Matches[1]
        $body = $Matches[2]

        foreach ($line in $yamlContent -split "`n") {
            $line = $line.Trim()
            if ($line -match "^(\w+):\s*(.*)$") {
                $key = $Matches[1]
                $value = $Matches[2].Trim()

                # Handle quoted strings
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $Matches[1]
                }

                $frontMatter[$key] = $value
            }
            elseif ($line -match "^\s+-\s+(.+)$") {
                # Handle array items (tags)
                $lastKey = ($frontMatter.Keys | Select-Object -Last 1)
                if ($frontMatter[$lastKey] -isnot [array]) {
                    $frontMatter[$lastKey] = @()
                }
                $frontMatter[$lastKey] += $Matches[1].Trim()
            }
        }
    }

    return @{
        FrontMatter = $frontMatter
        Body = $body
    }
}

function Generate-Slug {
    param([string]$Title)

    $slug = $Title.ToLower()
    $slug = $slug -replace "[^a-z0-9\s-]", ""
    $slug = $slug -replace "\s+", "-"
    $slug = $slug -replace "-+", "-"
    $slug = $slug.Trim("-")

    return $slug
}

function Extract-Description {
    param([string]$Body)

    # Try to extract from TL;DR section
    if ($Body -match "(?s)##\s*TL;DR\s*\r?\n\r?\n(.*?)(?:\r?\n\r?\n---|\r?\n\r?\n##)") {
        $tldr = $Matches[1].Trim()
        # Clean up bullet points
        $tldr = $tldr -replace "^\s*-\s*", ""
        $tldr = $tldr -replace "\r?\n\s*-\s*", " "
        $tldr = $tldr -replace "\r?\n", " "
        if ($tldr.Length -gt 200) {
            $tldr = $tldr.Substring(0, 197) + "..."
        }
        return $tldr
    }

    # Fall back to first paragraph
    $paragraphs = $Body -split "\r?\n\r?\n" | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }
    if ($paragraphs.Count -gt 0) {
        $firstPara = $paragraphs[0].Trim()
        if ($firstPara.Length -gt 200) {
            $firstPara = $firstPara.Substring(0, 197) + "..."
        }
        return $firstPara
    }

    return "A homelab blog post"
}

function Transform-ToHugo {
    param(
        [hashtable]$Parsed,
        [string]$FileName
    )

    $fm = $Parsed.FrontMatter
    $body = $Parsed.Body

    # Determine the date
    $date = if ($fm["publish_date"]) { $fm["publish_date"] }
            elseif ($fm["created"]) { $fm["created"] }
            else { (Get-Date).ToString("yyyy-MM-dd") }

    # Generate slug
    $slug = Generate-Slug -Title $fm["title"]

    # Get categories from series
    $series = $fm["series"]
    $categories = if ($series -and $SeriesMapping.ContainsKey($series)) {
        $SeriesMapping[$series]
    } else {
        @("Homelab")
    }

    # Get tags
    $tags = if ($fm["tags"] -is [array]) { $fm["tags"] } else { @("homelab") }

    # Extract description
    $description = Extract-Description -Body $body

    # Build Hugo front matter
    $hugoFm = @"
---
title: "$($fm["title"])"
description: "$description"
date: $date
slug: $slug
categories:
$(($categories | ForEach-Object { "    - $_" }) -join "`n")
tags:
$(($tags | ForEach-Object { "    - $_" }) -join "`n")
---
"@

    # Clean up body - remove duplicate title if present
    $body = $body -replace "(?m)^#\s+$([regex]::Escape($fm["title"]))\s*\r?\n", ""

    # Remove Obsidian wiki links [[...]]
    $body = $body -replace "\[\[([^\]|]+)\|([^\]]+)\]\]", '$2'
    $body = $body -replace "\[\[([^\]]+)\]\]", '$1'

    return "$hugoFm`n$body"
}

function Get-OutputFileName {
    param([string]$Title)

    $slug = Generate-Slug -Title $Title
    return "$slug.md"
}

# Main execution
Write-Host "`n=== Obsidian to Hugo Blog Sync ===" -ForegroundColor Magenta
Write-Host "Obsidian: $ObsidianPath"
Write-Host "Blog: $PostsPath`n"

if ($DryRun) {
    Write-Status "Running in DRY RUN mode - no changes will be made" "DryRun"
    Write-Host ""
}

# Validate paths
if (-not (Test-Path $ObsidianPath)) {
    Write-Status "Obsidian path not found: $ObsidianPath" "Error"
    exit 1
}

if (-not (Test-Path $PostsPath)) {
    Write-Status "Blog posts path not found: $PostsPath" "Error"
    exit 1
}

# Find posts to sync
$postsToSync = @()
$allPosts = Get-ChildItem -Path $ObsidianPath -Filter "Blog Post*.md"

foreach ($post in $allPosts) {
    $content = Get-Content -Path $post.FullName -Raw -Encoding UTF8
    $parsed = Parse-FrontMatter -Content $content

    $status = $parsed.FrontMatter["status"]
    $title = $parsed.FrontMatter["title"]

    if ($status -eq "ready" -or $status -eq "scheduled") {
        $postsToSync += @{
            File = $post
            Parsed = $parsed
            Status = $status
            Title = $title
        }
    }
}

if ($postsToSync.Count -eq 0) {
    Write-Status "No posts found with status: ready or scheduled" "Warning"
    Write-Host "To sync a post, add 'status: ready' or 'status: scheduled' to its front matter."
    exit 0
}

Write-Status "Found $($postsToSync.Count) post(s) to sync:" "Info"
foreach ($p in $postsToSync) {
    Write-Host "  - $($p.Title) [$($p.Status)]"
}
Write-Host ""

# Process each post
$synced = 0
$skipped = 0

foreach ($post in $postsToSync) {
    $outputFileName = Get-OutputFileName -Title $post.Title
    $outputPath = Join-Path $PostsPath $outputFileName

    # Check if file exists and hasn't changed
    if ((Test-Path $outputPath) -and -not $Force) {
        $existingContent = Get-Content -Path $outputPath -Raw -Encoding UTF8
        $newContent = Transform-ToHugo -Parsed $post.Parsed -FileName $post.File.Name

        # Simple comparison (ignoring whitespace differences)
        if (($existingContent -replace "\s+", "") -eq ($newContent -replace "\s+", "")) {
            Write-Status "Skipping (unchanged): $($post.Title)" "Warning"
            $skipped++
            continue
        }
    }

    if ($DryRun) {
        Write-Status "Would sync: $($post.Title) -> $outputFileName" "DryRun"
        $synced++
    }
    else {
        try {
            $hugoContent = Transform-ToHugo -Parsed $post.Parsed -FileName $post.File.Name
            $hugoContent | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline
            Write-Status "Synced: $($post.Title) -> $outputFileName" "Success"
            $synced++
        }
        catch {
            Write-Status "Failed to sync $($post.Title): $_" "Error"
        }
    }
}

Write-Host ""
Write-Status "Sync complete: $synced synced, $skipped skipped" "Info"

# Git operations
if ($Push -and -not $DryRun -and $synced -gt 0) {
    Write-Host ""
    Write-Status "Pushing to GitHub..." "Info"

    Push-Location $BlogPath
    try {
        git add content/posts/*.md
        $commitMsg = "Sync $synced post(s) from Obsidian"
        git commit -m $commitMsg
        git push
        Write-Status "Pushed to GitHub successfully" "Success"
    }
    catch {
        Write-Status "Git operation failed: $_" "Error"
    }
    finally {
        Pop-Location
    }
}
elseif ($Push -and $synced -eq 0) {
    Write-Status "Nothing to push - no posts were synced" "Warning"
}

Write-Host ""
