# ============================================================
# WordPress to Hugo Content Extractor
# Site: papowhovian.com.br
# ============================================================
param(
    [string]$BaseUrl   = "https://papowhovian.com.br",
    [string]$OutputDir = "$PSScriptRoot\.."
)

$ErrorActionPreference = "Stop"
$apiBase   = "$BaseUrl/wp-json/wp/v2"
$outputDir = (Resolve-Path $OutputDir).Path
$contentDir = "$outputDir\content"
$staticDir  = "$outputDir\static"
$imagesDir  = "$staticDir\images"
$dataDir    = "$outputDir\data"

Write-Host "=== WordPress to Hugo Extractor ===" -ForegroundColor Cyan
Write-Host "Source : $BaseUrl"
Write-Host "Output : $outputDir"
Write-Host ""

# Unicode chars used in output (keep script source ASCII-safe for PS5.1)
$uLDQ   = [char]0x201C  # left double quote
$uRDQ   = [char]0x201D  # right double quote
$uLSQ   = [char]0x2018  # left single quote
$uRSQ   = [char]0x2019  # right single quote
$uEnD   = [char]0x2013  # en dash
$uEmD   = [char]0x2014  # em dash
$uEll   = [char]0x2026  # ellipsis
$uLAQ   = [char]0x00AB  # left angle quote
$uRAQ   = [char]0x00BB  # right angle quote
$uBull  = [char]0x2022  # bullet
$uCopy  = [char]0x00A9  # copyright
$uReg   = [char]0x00AE  # registered

# ---- Helpers ----

function Save-Image {
    param([string]$url, [string]$destDir)
    if ([string]::IsNullOrWhiteSpace($url)) { return "" }
    $filename = [System.IO.Path]::GetFileName(($url -split '\?')[0])
    if ([string]::IsNullOrWhiteSpace($filename)) { return $url }
    $destPath = Join-Path $destDir $filename
    if (-not (Test-Path $destPath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            Write-Host "      [img] $filename" -ForegroundColor DarkGray
        } catch {
            Write-Warning "      Failed to download: $url"
            return $url
        }
    }
    $rel = $destPath.Replace($staticDir, "").Replace("\", "/")
    return $rel
}

function ConvertTo-Markdown {
    param([string]$html)
    if ([string]::IsNullOrWhiteSpace($html)) { return "" }
    $m = $html

    # Remove WordPress shortcodes
    $m = [regex]::Replace($m, '\[/?[a-z_]+[^\]]*\]', '')

    # Headers
    foreach ($n in 1..6) {
        $tag = "h$n"
        $hashes = "#" * $n
        $m = [regex]::Replace($m, "(?s)<$tag[^>]*>(.*?)</$tag>", {
            param($x)
            $inner = [regex]::Replace($x.Groups[1].Value, '<[^>]+>', '').Trim()
            "`n$hashes $inner`n"
        })
    }

    # Bold / italic
    $m = [regex]::Replace($m, '(?s)<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>', { param($x) "**$($x.Groups[1].Value)**" })
    $m = [regex]::Replace($m, '(?s)<(?:em|i)[^>]*>(.*?)</(?:em|i)>',         { param($x) "*$($x.Groups[1].Value)*" })

    # Links
    $m = [regex]::Replace($m, '(?s)<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>', {
        param($x) "[$($x.Groups[2].Value)]($($x.Groups[1].Value))"
    })

    # Images
    $m = [regex]::Replace($m, '<img[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*/?>', { param($x) "![$($x.Groups[2].Value)]($($x.Groups[1].Value))" })
    $m = [regex]::Replace($m, '<img[^>]*src="([^"]*)"[^>]*/?>',                   { param($x) "![]($($x.Groups[1].Value))" })

    # Lists
    $m = [regex]::Replace($m, '(?s)<li[^>]*>(.*?)</li>', { param($x) "- $($x.Groups[1].Value.Trim())`n" })
    $m = $m -replace '<[uo]l[^>]*>', "`n"
    $m = $m -replace '</[uo]l>',     "`n"

    # Blockquote
    $m = [regex]::Replace($m, '(?s)<blockquote[^>]*>(.*?)</blockquote>', { param($x) "> $($x.Groups[1].Value.Trim())`n" })

    # Paragraphs and breaks
    $m = $m -replace '<br\s*/?>', "`n"
    $m = $m -replace '<p[^>]*>',  ''
    $m = $m -replace '</p>',       "`n`n"
    $m = $m -replace '<div[^>]*>', ''
    $m = $m -replace '</div>',     "`n"

    # Remove remaining tags
    $m = [regex]::Replace($m, '<[^>]+>', '')

    # HTML entities (all ASCII-safe in source)
    $entities = [ordered]@{
        '&nbsp;'    = ' '
        '&amp;'     = '&'
        '&lt;'      = '<'
        '&gt;'      = '>'
        '&quot;'    = '"'
        '&#8220;'   = $uLDQ
        '&#8221;'   = $uRDQ
        '&#8216;'   = $uLSQ
        '&#8217;'   = $uRSQ
        '&#8211;'   = $uEnD
        '&#8212;'   = $uEmD
        '&#038;'    = '&'
        '&#8230;'   = $uEll
        '&rsquo;'   = $uRSQ
        '&ldquo;'   = $uLDQ
        '&rdquo;'   = $uRDQ
        '&mdash;'   = $uEmD
        '&ndash;'   = $uEnD
        '&hellip;'  = $uEll
        '&laquo;'   = $uLAQ
        '&raquo;'   = $uRAQ
        '&#8226;'   = $uBull
        '&copy;'    = $uCopy
        '&reg;'     = $uReg
        '&apos;'    = "'"
    }
    foreach ($k in $entities.Keys) { $m = $m.Replace($k, $entities[$k]) }

    # Cleanup whitespace
    $m = [regex]::Replace($m, '[ \t]+',     ' ')
    $m = [regex]::Replace($m, '(\r?\n){3,}', "`n`n")

    return $m.Trim()
}

function Escape-Yaml {
    param([string]$s)
    $s = $s -replace '\\', '\\'
    $s = $s -replace '"',  '\"'
    $s = ($s -replace "`r`n",' ') -replace "`n",' '
    return $s.Trim()
}

function Write-Utf8 {
    param([string]$path, [string]$content)
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

function ToYamlList {
    param([string[]]$items)
    if ($items.Count -eq 0) { return '[]' }
    $q = $items | ForEach-Object { "`"$($_ -replace '"','\"')`"" }
    return "[" + ($q -join ", ") + "]"
}

# ---- Fetch taxonomies and authors ----

Write-Host "Fetching categories..." -ForegroundColor Yellow
$catList = Invoke-RestMethod ($apiBase + '/categories?per_page=100')
$catMap  = @{}
foreach ($c in $catList) { $catMap[$c.id] = $c.name }
Write-Host "  $($catList.Count) categories"

Write-Host "Fetching tags..." -ForegroundColor Yellow
$tagList = Invoke-RestMethod ($apiBase + '/tags?per_page=100')
$tagMap  = @{}
foreach ($t in $tagList) { $tagMap[$t.id] = $t.name }
Write-Host "  $($tagList.Count) tags"

Write-Host "Fetching authors..." -ForegroundColor Yellow
$authorList = Invoke-RestMethod ($apiBase + '/users?per_page=100')
$authorMap  = @{}
foreach ($a in $authorList) {
    $authorMap[$a.id] = @{
        name        = $a.name
        slug        = $a.slug
        description = $a.description
        avatar      = if ($a.avatar_urls -and $a.avatar_urls.'96') { $a.avatar_urls.'96' } else { "" }
    }
}
Write-Host "  $($authorList.Count) authors"

# Save authors as Hugo data file
$authData = @{}
foreach ($a in $authorList) {
    $authData[$a.slug] = @{
        name        = $a.name
        description = $a.description
        avatar      = if ($a.avatar_urls -and $a.avatar_urls.'96') { $a.avatar_urls.'96' } else { "" }
    }
}
Write-Utf8 "$dataDir\authors.json" ($authData | ConvertTo-Json -Depth 5)
Write-Host "  Saved: data/authors.json"

# ---- Fetch comments (may be restricted) ----

Write-Host "`nFetching comments..." -ForegroundColor Yellow
$allComments = @()
try {
    $page = 1
    do {
        $batch = Invoke-RestMethod ($apiBase + "/comments?per_page=100&page=$page") -ErrorAction Stop
        if ($batch.Count -eq 0) { break }
        $allComments += $batch
        $page++
    } while ($batch.Count -eq 100)
    Write-Host "  $($allComments.Count) approved comments"
} catch {
    Write-Host "  Comments API not publicly available (401)" -ForegroundColor DarkYellow
    Write-Host "  To migrate comments: export WXR from WordPress admin (Tools > Export > All content)"
}

$commentsByPost = @{}
foreach ($c in $allComments) {
    if (-not $commentsByPost.ContainsKey($c.post)) { $commentsByPost[$c.post] = @() }
    $commentsByPost[$c.post] += $c
}

# ---- Fetch and save posts ----

Write-Host "`nFetching posts..." -ForegroundColor Yellow
$posts = Invoke-RestMethod ($apiBase + '/posts?per_page=100&_embed')
Write-Host "  $($posts.Count) posts found"
Write-Host ""

$postMeta = @()
$i = 0
foreach ($post in $posts) {
    $i++
    $rawTitle = [regex]::Replace($post.title.rendered, '<[^>]+>', '')
    $title    = ConvertTo-Markdown $rawTitle
    $title    = [regex]::Replace($title, '^#+\s*', '')
    $slug     = $post.slug

    Write-Host "  [$i/$($posts.Count)] $slug" -ForegroundColor White

    # Author
    $aId   = $post.author
    $aName = if ($authorMap.ContainsKey($aId)) { $authorMap[$aId].name } else { "" }
    $aSlug = if ($authorMap.ContainsKey($aId)) { $authorMap[$aId].slug } else { "" }

    # Categories and tags
    $cats = @($post.categories | Where-Object { $catMap.ContainsKey($_) } | ForEach-Object { $catMap[$_] })
    $tgs  = @($post.tags       | Where-Object { $tagMap.ContainsKey($_)  } | ForEach-Object { $tagMap[$_] })

    # Featured image
    $thumb    = ""
    $thumbAlt = ""
    try {
        $fm = $post._embedded.'wp:featuredmedia'
        if ($fm -and $fm.Count -gt 0 -and $fm[0].source_url) {
            $thumb    = Save-Image -url $fm[0].source_url -destDir "$imagesDir\posts"
            $thumbAlt = if ($fm[0].alt_text) { $fm[0].alt_text } else { "" }
        }
    } catch {}

    # Excerpt (strip HTML)
    $excerpt = [regex]::Replace($post.excerpt.rendered, '<[^>]+>', '').Trim()
    $excerpt = $excerpt -replace '\[\.\.\.\]', '...'
    $excerpt = $excerpt -replace "\[$uEll\]", '...'

    # Content
    $content = ConvertTo-Markdown $post.content.rendered

    # Comment count for this post
    $postComments = if ($commentsByPost.ContainsKey($post.id)) { $commentsByPost[$post.id] } else { @() }

    # Build frontmatter
    $frontmatter = "---`n"
    $frontmatter += "title: `"$(Escape-Yaml $title)`"`n"
    $frontmatter += "date: $($post.date)`n"
    $frontmatter += "lastmod: $($post.modified)`n"
    $frontmatter += "author: `"$(Escape-Yaml $aName)`"`n"
    $frontmatter += "authorSlug: `"$aSlug`"`n"
    $frontmatter += "categories: $(ToYamlList $cats)`n"
    $frontmatter += "tags: $(ToYamlList $tgs)`n"
    $frontmatter += "slug: `"$slug`"`n"
    $frontmatter += "thumbnail: `"$(Escape-Yaml $thumb)`"`n"
    $frontmatter += "thumbnailAlt: `"$(Escape-Yaml $thumbAlt)`"`n"
    $frontmatter += "excerpt: `"$(Escape-Yaml $excerpt)`"`n"
    $frontmatter += "commentCount: $($postComments.Count)`n"
    $frontmatter += "wpId: $($post.id)`n"
    $frontmatter += "draft: false`n"
    $frontmatter += "---`n`n"
    $frontmatter += $content

    Write-Utf8 "$contentDir\posts\$slug.md" $frontmatter

    # Collect for Disqus XML
    $postMeta += @{ id=$post.id; url=$post.link; title=$title; slug=$slug; date=$post.date; comments=$postComments }
}

# ---- Fetch and save pages ----

Write-Host "`nFetching pages..." -ForegroundColor Yellow
$pages = Invoke-RestMethod ($apiBase + '/pages?per_page=100&_embed')
Write-Host "  $($pages.Count) pages"
Write-Host ""

foreach ($page in $pages) {
    $title   = [regex]::Replace($page.title.rendered, '<[^>]+>', '')
    $slug    = $page.slug
    $content = ConvertTo-Markdown $page.content.rendered

    Write-Host "  $slug" -ForegroundColor White

    $thumb = ""
    try {
        $fm2 = $page._embedded.'wp:featuredmedia'
        if ($fm2 -and $fm2.Count -gt 0 -and $fm2[0].source_url) {
            $thumb = Save-Image -url $fm2[0].source_url -destDir "$imagesDir\pages"
        }
    } catch {}

    $frontmatter = "---`n"
    $frontmatter += "title: `"$(Escape-Yaml $title)`"`n"
    $frontmatter += "date: $($page.date)`n"
    $frontmatter += "lastmod: $($page.modified)`n"
    $frontmatter += "slug: `"$slug`"`n"
    $frontmatter += "thumbnail: `"$(Escape-Yaml $thumb)`"`n"
    $frontmatter += "wpId: $($page.id)`n"
    $frontmatter += "draft: false`n"
    $frontmatter += "---`n`n"
    $frontmatter += $content

    if ($slug -in @("home", "home-2", "")) {
        Write-Utf8 "$contentDir\_index.md" $frontmatter
    } else {
        Write-Utf8 "$contentDir\pages\$slug.md" $frontmatter
    }
}

# ---- Download global assets ----

Write-Host "`nDownloading global assets..." -ForegroundColor Yellow
Save-Image "https://papowhovian.com.br/wp-content/uploads/2016/02/logo-papo-whovian.png"  $staticDir | Out-Null
Save-Image "https://ultima7.com.br/papowhovian/wp-content/uploads/2016/01/favico.png"     $staticDir | Out-Null
Save-Image "https://papowhovian.com.br/wp-content/uploads/2015/01/sky-828648_1920.jpg"    $imagesDir | Out-Null

# ---- Generate Disqus import XML ----

Write-Host "`nGenerating Disqus import XML..." -ForegroundColor Yellow

$xml = '<?xml version="1.0" encoding="UTF-8"?>' + "`n"
$xml += '<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" '
$xml += 'xmlns:dsq="http://www.disqus.com/forums/papowhovian/" '
$xml += 'xmlns:dc="http://purl.org/dc/elements/1.1/" '
$xml += 'xmlns:wp="http://wordpress.org/export/1.0/">' + "`n"
$xml += "  <channel>`n"
$xml += "    <title>Papo Whovian</title>`n"
$xml += "    <link>https://papowhovian.com.br</link>`n"
$xml += "    <description>Sua biblioteca nacional sobre tudo o que rola no universo de Doctor Who</description>`n"

foreach ($pm in $postMeta) {
    $safeTitle = [System.Security.SecurityElement]::Escape($pm.title)
    $xml += "    <item>`n"
    $xml += "      <title>$safeTitle</title>`n"
    $xml += "      <link>$($pm.url)</link>`n"
    $xml += "      <dsq:thread_identifier>$($pm.slug)</dsq:thread_identifier>`n"
    $xml += "      <wp:post_date_gmt>$($pm.date)</wp:post_date_gmt>`n"
    $xml += "      <content:encoded><![CDATA[]]></content:encoded>`n"

    foreach ($c in $pm.comments) {
        $cAuthor  = [System.Security.SecurityElement]::Escape($c.author_name)
        $cEmail   = [System.Security.SecurityElement]::Escape($c.author_email)
        $cRaw     = [regex]::Replace($c.content.rendered, '<[^>]+>', '').Trim()
        $approved = if ($c.status -eq "approved") { "1" } else { "0" }
        $parentId = if ($c.parent -gt 0) { $c.parent } else { "" }

        $xml += "      <wp:comment>`n"
        $xml += "        <wp:comment_id>$($c.id)</wp:comment_id>`n"
        $xml += "        <wp:comment_author>$cAuthor</wp:comment_author>`n"
        $xml += "        <wp:comment_author_email>$cEmail</wp:comment_author_email>`n"
        $xml += "        <wp:comment_author_url>$($c.author_url)</wp:comment_author_url>`n"
        $xml += "        <wp:comment_date_gmt>$($c.date_gmt)</wp:comment_date_gmt>`n"
        $xml += "        <wp:comment_content><![CDATA[$cRaw]]></wp:comment_content>`n"
        $xml += "        <wp:comment_approved>$approved</wp:comment_approved>`n"
        $xml += "        <wp:comment_parent>$parentId</wp:comment_parent>`n"
        $xml += "      </wp:comment>`n"
    }

    $xml += "    </item>`n"
}

$xml += "  </channel>`n"
$xml += "</rss>`n"

Write-Utf8 "$dataDir\disqus-import.xml" $xml
Write-Host "  Saved: data/disqus-import.xml"

# ---- Summary ----

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host "  Posts    : $($posts.Count)  ->  content/posts/"
Write-Host "  Pages    : $($pages.Count)   ->  content/pages/"
Write-Host "  Comments : $($allComments.Count)  ->  data/disqus-import.xml"
Write-Host "  Images   : $imagesDir"
Write-Host ""
Write-Host "To import comments into Disqus:"
Write-Host "  1. Create account at disqus.com and register site 'papowhovian'"
Write-Host "  2. Go to Admin -> Moderation -> Import -> WordPress"
Write-Host "  3. Upload data/disqus-import.xml"
