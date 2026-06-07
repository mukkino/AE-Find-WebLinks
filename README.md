# AE-Find-WebLinks

AE-Find-WebLinks is a PowerShell command-line tool for extracting, filtering, saving, and optionally crawling web links from either a single web page or a text file containing many source URLs.

It is built for link discovery, archive preparation, download-list building, deduplication, filtering, blacklist handling, long-running URL jobs, failed-URL tracking, CSV logging, optional parallel processing, and maintenance of large text URL lists.

The script does **not** require a browser, Selenium, Playwright, ChromeDriver, or external PowerShell modules. It downloads the raw HTTP response and extracts links from common places such as HTML attributes, raw text, script blocks, JSON-like content, CSS `url(...)` references, `noscript` blocks, and embedded URL patterns.

It is a raw-response extraction and crawling tool, not a browser. It does **not** execute JavaScript or render web pages.

---

## Current version

**Latest version:** `1.7.0`

Version `1.7.0` adds controlled crawling and link-following support while preserving the old default behaviour.

By default, AE-Find-WebLinks still scans only the source URL or URLs you provide. Crawling is disabled unless explicitly enabled with `-FollowDepth`, `-FollowUntilExhausted`, `-FollowToEnd`, or `-UnlimitedFollowDepth`.

This version adds:

* Optional crawl depth control.
* Optional crawl-until-exhausted mode.
* Same-host and same-domain crawl boundaries.
* Optional subdomain crawling.
* Optional seed-path/subtree crawling.
* Crawl page safety caps.
* Optional `robots.txt` enforcement, disabled by default.
* Better source-file URL extraction.
* Fixes for crawl seed handling, empty-link collections, PowerShell parser edge cases, and reserved PowerShell variable collisions.

Use this version if you want the original one-page extraction behaviour, or if you need controlled recursive crawling for archive discovery, download-list generation, or path-limited link discovery.

---

## Requirements

* Windows PowerShell 5.1 or PowerShell 7+.
* PowerShell 7+ is required only when using parallel processing with `-ThrottleLimit` greater than `1`.
* No external PowerShell modules required.
* No browser required.

Crawl mode is intentionally sequential in this version. If crawling is enabled, use `-ThrottleLimit 1`.

---

## Main capabilities

AE-Find-WebLinks can:

* Scan one URL.
* Scan many URLs from a text file.
* Extract links from raw HTTP responses.
* Extract URL tokens from less-clean source files, including copied text, logs, CSV-style lines, and HTML-like content.
* Match links using one wildcard pattern or multiple wildcard patterns.
* Use `Any` or `All` matching logic for include patterns.
* Exclude links using one or more wildcard patterns.
* Use `Any` or `All` matching logic for exclusion patterns.
* Write matching links to a plain text output file.
* Append to an existing output file or create a fresh output file.
* Avoid writing duplicate links already present in the output file.
* Optionally keep duplicate matches found within the same page.
* Preserve or ignore URL fragments during deduplication.
* Use one or more exact-URL blacklist files.
* Apply blacklists to input URLs, output links, or both.
* Resume interrupted non-crawl file-mode runs using a progress file.
* Detect changed run settings before resuming.
* Retry failed requests.
* Honour HTTP and meta-refresh redirect limits.
* Optionally fetch a page twice and keep the larger response.
* Use a custom User-Agent.
* Use an HTTP proxy.
* Log per-URL processing statistics to CSV.
* Save failed source URLs to a separate tab-separated file.
* Use independent append/new modes for output, CSV log, and failed URL files.
* Process URL lists sequentially or, outside crawl mode, in parallel.
* Deduplicate and sort files before or after a scraping run.
* Clean failed or stale maintenance temporary files created by deduplication and sorting.
* Run standalone maintenance commands without fetching URLs.
* Protect against dangerous file collisions.
* Warn when failure rates are high.
* Expose operational limits as command-line parameters instead of hardcoded values.
* Show built-in help with `-Help` or `-h`.
* Start a guided interactive command builder with `-InteractiveHelp` or `-Interactive`.
* When started without parameters, ask whether to show help, open the guided command builder, or exit.

---

## Crawling and link following

AE-Find-WebLinks can optionally follow links discovered on source pages.

The crawler has two separate behaviours:

1. **Discovery:** which links are allowed to be followed.
2. **Saving:** which links are written to the output file.

Crawl discovery intentionally ignores `SearchPattern`. This is important because intermediate index, category, navigation, or pagination pages may not match your search pattern, but they may lead to links that do.

`SearchPattern` controls only what is written to the output file.

For example, if you search for:

```powershell
"*news*story*"
```

the crawler may still follow pages that do not contain `comic` or `picture` in the URL, as long as those pages are allowed by the crawl scope. Only links matching `*news*story*` are saved.

---

## Crawl depth

Use `-FollowDepth` to decide how far links should be followed.

```powershell
-FollowDepth 0
```

Default behaviour. No crawling. Only the supplied source URL or URLs are scanned.

```powershell
-FollowDepth 1
```

Scan the source page, then fetch links found on that page.

```powershell
-FollowDepth 2
```

Scan the source page, fetch links found on that page, then fetch links found one level deeper.

```powershell
-FollowDepth -1
```

Crawl until there are no more allowed unseen links.

The clearer equivalent is:

```powershell
-FollowUntilExhausted
```

Aliases are also available:

```powershell
-FollowToEnd
-UnlimitedFollowDepth
```

---

## Crawl page cap

Use `-MaxFollowPages` to limit how many pages the crawler is allowed to schedule and fetch.

Default:

```powershell
-MaxFollowPages 1000
```

This prevents accidental huge crawls.

To remove the cap:

```powershell
-MaxFollowPages 0
```

Use `-MaxFollowPages 0` carefully, especially with `-FollowUntilExhausted`, because the crawl will stop only when no more allowed unseen links remain.

---

## Crawl scope

Use `-FollowScope` to control which hosts or domains may be crawled.

Available values:

```powershell
-FollowScope SameDomain
-FollowScope SameHost
-FollowScope Any
```

Default:

```powershell
-FollowScope SameDomain
```

### SameDomain

`SameDomain` allows crawling within the same registrable domain area, with safe defaults around apex and `www` hosts.

Example seed:

```text
https://example.com/1
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
https://www.example.com/1
```

Rejected by default:

```text
https://blog.example.com/1
https://other-site.com/1
```

### SameHost

`SameHost` is stricter. It allows only the exact same hostname as the seed URL.

Example seed:

```text
https://example.com/1
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
```

Rejected:

```text
https://www.example.com/1
https://blog.example.com/1
https://other-site.com/1
```

Use `SameHost` when you want the crawl locked to the exact host from the input URL.

### Any

`Any` allows external domains, subject to private/internal URL protection, blacklist checks, file-type skipping, depth limits, page caps, and optional `robots.txt` enforcement.

Use it carefully.

---

## Subdomain handling

By default, subdomain crawling is disabled except for the seed host, apex host, and `www` host handling used by `SameDomain`.

Enable wider subdomain crawling with:

```powershell
-FollowSubdomains
```

Limit how many subdomain levels may be followed with:

```powershell
-MaxSubdomainDepth 1
```

`1` means direct subdomains only.

Example:

```text
blog.example.com
downloads.example.com
```

`0` means unlimited subdomain depth.

Example:

```text
a.b.c.example.com
```

Default:

```powershell
-FollowSubdomains:$false
-MaxSubdomainDepth 1
```

The recommended default is to keep subdomain crawling disabled unless you know the site structure needs it.

---

## Path-limited crawling

Use `-FollowPathScope SeedPath` to keep crawling only inside the starting URL path/subtree.

This is useful when a source URL points to a specific archive section and you do not want the crawler to wander sideways into other parts of the same site.

Example seed:

```text
https://example.com/1
```

With:

```powershell
-FollowPathScope SeedPath
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
https://example.com/1/2/3
```

Rejected:

```text
https://example.com/2
https://example.com/10
https://example.com/1-other
```

The path check is segment-aware, so `/1` does not accidentally match `/10`.

Default:

```powershell
-FollowPathScope Any
```

---

## robots.txt support

AE-Find-WebLinks can enforce `robots.txt`, but this is disabled by default.

Enable it with:

```powershell
-EnforceRobotsTxt
```

Set the user-agent token used for robots matching with:

```powershell
-RobotsUserAgent "AE-Find-WebLinks"
```

When enabled, the script checks `robots.txt` before fetching:

* initial source URLs;
* crawled pages;
* redirect targets.

The script caches `robots.txt` rules per origin to avoid repeatedly downloading the same file.

Missing or `4xx` `robots.txt` responses are treated as allowed. Network errors or `5xx` responses fail closed for that origin while enforcement is enabled.

Supported robots rules include:

* `User-agent`
* `Allow`
* `Disallow`
* `*` wildcards
* `$` end anchors
* longest-match rule selection
* `Allow` winning ties

Unsupported extensions such as `Crawl-delay`, `Sitemap`, and `Request-rate` are ignored.

Use `-DelaySeconds` for throttling.

---

## Example commands

### Scan one page only

```powershell
.\AE-Find-WebLinks.ps1 "https://example.com" "*download*" ".\matched-links.txt" New
```

### Scan many source URLs from a file

```powershell
.\AE-Find-WebLinks.ps1 ".\source-urls.txt" "*download*" ".\matched-links.txt" New File
```

### Crawl one level on the same domain

```powershell
.\AE-Find-WebLinks.ps1 "https://example.com" "*download*" ".\matched-links.txt" New -FollowDepth 1 -FollowScope SameDomain
```

### Crawl until exhausted inside the same path subtree

```powershell
.\AE-Find-WebLinks.ps1 ".\download-now.txt" "*news*story*" ".\matched-links.txt" Append File -BlacklistFile ".\already-dowloaded.txt" -LogCsv ".\run-log2.csv" -FailedUrlFile ".\failed-urls.txt" -DeduplicateFiles -SortOutput:$true -FollowUntilExhausted -FollowScope SameHost -FollowPathScope SeedPath -MaxFollowPages 0
```

### Same command, but with a safety cap

```powershell
.\AE-Find-WebLinks.ps1 ".\download-now.txt" "*news*story*" ".\matched-links.txt" Append File -BlacklistFile ".\already-dowloaded.txt" -LogCsv ".\run-log.csv" -FailedUrlFile ".\failed-urls.txt" -DeduplicateFiles -SortOutput:$true -FollowUntilExhausted -FollowScope SameHost -FollowPathScope SeedPath -MaxFollowPages 5000
```

### Enable robots.txt enforcement

```powershell
.\AE-Find-WebLinks.ps1 "https://example.com" "*download*" ".\matched-links.txt" New -FollowDepth 2 -FollowScope SameDomain -EnforceRobotsTxt
```

---

## Important limitations

AE-Find-WebLinks is not a browser.

It does not:

* execute JavaScript;
* click buttons;
* scroll pages;
* log in to websites;
* solve captchas;
* render dynamic pages;
* discover links created only after browser-side JavaScript execution.

It works best on links present in the raw HTTP response, including HTML, text, CSS, script text, JSON-like payloads, and embedded URL patterns.

For JavaScript-rendered websites, use a browser-based crawler instead, or provide AE-Find-WebLinks with URLs from already-rendered/exported pages.

---

## Recommended safe crawl setup

For most archive or download-list jobs, start with:

```powershell
-FollowScope SameHost
-FollowPathScope SeedPath
-MaxFollowPages 5000
```

Then only loosen the settings if needed.

Use:

```powershell
-FollowScope SameDomain
```

when the site legitimately moves between `example.com` and `www.example.com`.

Use:

```powershell
-FollowSubdomains
```

only when the target archive is known to span subdomains.

Use:

```powershell
-MaxFollowPages 0
```

only when you are comfortable with an unbounded crawl.

---
