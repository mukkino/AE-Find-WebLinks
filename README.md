# Find-WebLinks

Find-WebLinks is a PowerShell script that extracts web links from a single web page or from a text file containing multiple URLs.

It is useful when you need to scan pages, collect matching links, process long URL lists, or keep a simple audit trail of what was found, skipped, or failed.

The script does not require a browser, browser driver, Selenium, Playwright, or external PowerShell modules. It uses PowerShell’s built-in `Invoke-WebRequest`.

## What it does

- Scans one URL or a file containing many URLs
- Extracts links from HTML, scripts, JSON-like text, CSS references, and noscript blocks
- Filters links using wildcard patterns such as `*news*` or `*download*`
- Writes matching links to a text file
- Supports append or overwrite mode
- Retries failed requests
- Can fetch the same URL twice and keep the larger response
- Removes duplicates by default
- Supports exact URL blacklist files
- Can write a CSV log of each processed URL
- Can save failed URLs to a separate file
- Writes results after each page, so long runs keep partial progress

## How to use it

### 1. Download the script

Download or copy the file named:

```text
Find-WebLinks.ps1
```

Put it somewhere easy to find, for example:

```text
C:\Users\YourName\Desktop
```

or:

```text
C:\Temp
```

### 2. Open PowerShell

On Windows:

1. Press the **Start** button.
2. Type **PowerShell**.
3. Open **Windows PowerShell**.

You do not normally need to run it as Administrator.

### 3. Go to the folder where the script is saved

If the script is on your Desktop, type:

```powershell
cd Desktop
```

If the script is in `C:\Temp`, type:

```powershell
cd C:\Temp
```

### 4. Allow PowerShell to run the script if needed

If PowerShell blocks the script, run this command once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then press:

```text
Y
```

and press **Enter**.

### 5. Run the script

The basic format is:

```powershell
.\Find-WebLinks.ps1 "PAGE_OR_FILE" "WHAT_TO_FIND" "OUTPUT_FILE"
```

For example, to search BBC News for links containing the word `sport`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "bbc-links.txt" New
```

This will:

```text
Open the BBC News page
Find links containing sport
Save them into bbc-links.txt
Create a new output file
```

### 6. Understand the `*` character

The `*` means “anything”.

Examples:

```text
*sport*        finds links containing sport
*news*         finds links containing news
*download*     finds links containing download
*bbc*weather*  finds links containing bbc, then weather later in the link
```

So this:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*weather*" "weather-links.txt" New
```

means:

```text
Find all links on that page that contain weather.
```

## Common examples

### Search one web page and create a new output file

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "bbc-links.txt" New
```

Use this when you want to start fresh.

### Search one web page and add to an existing file

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*politics*" "bbc-links.txt" Append
```

Use this when you want to add more results to the same file.

### Search many web pages from a text file

Create a text file called:

```text
urls.txt
```

Inside it, put one web address per line:

```text
https://www.bbc.co.uk/news
https://www.bbc.co.uk/sport
https://www.bbc.co.uk/weather
```

Then run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File
```

This will:

```text
Read each URL from urls.txt
Visit each page
Find links containing news
Save matching links into matched-links.txt
```

### Save failed pages to a separate file

When scanning many URLs, some pages may fail because they are offline, slow, blocked, or invalid.

Use:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -FailedUrlFile "failed.txt"
```

Failed URLs will be saved into:

```text
failed.txt
```

### Create a CSV log

A CSV log is useful if you want a report showing what happened for each page.

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -LogCsv "run-log.csv"
```

The CSV file will show things like:

```text
Which URLs worked
Which URLs failed
How many links were found
How many links matched
How many links were written
```

### Use both failed URL tracking and CSV logging

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -LogCsv "run-log.csv" -FailedUrlFile "failed.txt"
```

This is the best option for larger jobs.

## Append vs New

You will usually use either `New` or `Append`.

```text
New     creates a fresh output file or overwrites the old one
Append  adds new results to the existing output file
```

Example using `New`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "links.txt" New
```

Example using `Append`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*weather*" "links.txt" Append
```

If you are unsure, use `New` when starting a new search.

## Url vs File

The script has two modes.

```text
Url   means the first thing you give it is one web page
File  means the first thing you give it is a text file containing many web pages
```

One web page:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "links.txt" New Url
```

Many web pages from a file:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*sport*" "links.txt" New File
```

Most of the time:

```text
Use Url when scanning one page
Use File when scanning a list of pages
```

## Useful options

### Retry slower websites

If a website is slow or unreliable, increase retries:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -RetryCount 5 -WaitSeconds 60
```

This means:

```text
Try each failed page up to 5 times
Wait 60 seconds between retries
```

### Reduce waiting between pages

By default, the script waits 5 seconds between URLs in File mode.

To go faster:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -DelaySeconds 0
```

Use this carefully. Do not hammer websites with too many requests.

### Disable the second fetch

By default, the script fetches each page twice and keeps the larger result.

To fetch each page only once:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File -SecondFetch:$false
```

### Use a blacklist file

Create a file called:

```text
blocked.txt
```

Put links you do not want in the final result:

```text
https://example.com/unwanted-page
https://example.com/another-page
```

Then run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "matched-links.txt" New File -BlacklistFile "blocked.txt"
```

The blacklist is for exact URLs only.

This blocks:

```text
https://example.com/unwanted-page
```

It does not automatically block:

```text
https://example.com/unwanted-page/other
```

## Output files

Depending on the options you use, the script may create these files:

```text
matched-links.txt   The links found by the script
failed.txt          URLs that failed to load
run-log.csv         A report of what happened for each URL
```

You can open `.txt` files with Notepad.

You can open `.csv` files with Excel.

## Troubleshooting

### PowerShell says scripts are disabled

Run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then run the script again.

### No links are found

Possible reasons:

```text
The page does not contain matching links
The search pattern is too specific
The links are created by JavaScript
The website blocked the request
The page requires login or cookies
```

Try a broader search pattern:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*" "all-links.txt" New
```

### The script finds fewer links than the browser shows

That can happen because the script does not run JavaScript.

Some modern websites build the page inside the browser after loading. This script cannot see links that only appear after that happens.

### The output file is empty

Check:

```text
Did you use the right search word?
Did the page load successfully?
Did the CSV log show any failures?
Did the links get skipped because they were duplicates?
```

For a larger job, run with logging:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "matched-links.txt" New File -LogCsv "run-log.csv" -FailedUrlFile "failed.txt"
```

## Disclaimer

This is a best-effort command-line link extraction tool, not a full browser.

It downloads the raw HTTP response and searches through the returned content. It does **not** execute JavaScript, render pages, click buttons, accept cookie banners, scroll pages, or wait for client-side frameworks such as React, Vue, or Angular to build the page.

If a link only appears after JavaScript runs in a real browser, this script may not see it.

Use it responsibly. Respect website terms of service, robots.txt guidance where applicable, rate limits, and copyright restrictions. Do not use it to overload websites or collect data you are not allowed to access.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- No external modules required
- No browser required
