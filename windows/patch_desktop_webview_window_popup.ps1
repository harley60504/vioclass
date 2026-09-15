param(
  [Parameter(Mandatory = $true)]
  [string]$WebViewSource
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WebViewSource)) {
  Write-Host "[VioClass WebView2] desktop_webview_window source not found: $WebViewSource"
  exit 0
}

$content = Get-Content -LiteralPath $WebViewSource -Raw
$marker = 'VioClass: preserve native WebView2 popup behavior'

if ($content.Contains($marker)) {
  Write-Host '[VioClass WebView2] popup patch already applied.'
  exit 0
}

$pattern = '(?s)\s*// Always use single window to load web page\.\s*webview_->add_NewWindowRequested\(.*?\)\s*\.Get\(\),\s*nullptr\);'

$replacement = @'

  // VioClass: preserve native WebView2 popup behavior.
  //
  // desktop_webview_window normally intercepts every NewWindowRequested event,
  // navigates the parent WebView to the requested URI, and marks the request as
  // handled. Twitch third-party sign-in opens a named about:blank popup first and
  // navigates that browsing context later. Redirecting the parent destroys the
  // popup/opener relationship and leaves the Twitch page at about:blank.
  //
  // According to WebView2 semantics, Handled = FALSE with no NewWindow supplied
  // lets WebView2 create its normal popup and returns the real WindowProxy to the
  // opener. That preserves window.open(), window.opener, named-target navigation,
  // postMessage, and window.close() for Twitch/Google/Amazon/Apple sign-in.
  webview_->add_NewWindowRequested(
      Callback<ICoreWebView2NewWindowRequestedEventHandler>(
          [](ICoreWebView2 *sender,
             ICoreWebView2NewWindowRequestedEventArgs *args) {
            args->put_Handled(false);
            return S_OK;
          })
          .Get(),
      nullptr);
'@

$patched = [regex]::Replace($content, $pattern, $replacement, 1)

if ($patched -eq $content) {
  Write-Error '[VioClass WebView2] popup patch target was not found; desktop_webview_window source layout may have changed.'
  exit 1
}

Set-Content -LiteralPath $WebViewSource -Value $patched -Encoding UTF8 -NoNewline
Write-Host '[VioClass WebView2] patched desktop_webview_window NewWindowRequested -> Handled(false).'
