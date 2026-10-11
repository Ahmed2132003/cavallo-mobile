# Cavallo search fix. Usage:
#   .\apply_search_fix.ps1 -BackendPath C:\dev\cavallo-app -MobilePath C:\dev\cavallo-mobile
# Backs up every replaced file as <name>.bak_search_fix. Use -Force to skip the "same as GitHub main" check.
param(
    [string]$BackendPath = (Join-Path (Get-Location) 'cavallo-app'),
    [string]$MobilePath  = (Join-Path (Get-Location) 'cavallo-mobile'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedHash([byte[]]$bytes) {
    $text = [System.Text.Encoding]::UTF8.GetString($bytes) -replace "`r`n", "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

foreach ($p in @($BackendPath, $MobilePath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Folder not found: $p  (use -BackendPath / -MobilePath)" }
}

$Files = @(
    @{
        Repo = 'app'
        Path = 'search/services.py'
        ExpectedHash = '5828b4bdbca7da304223daa15abd5377027eee487e458c50ceac800384d108e0'
        B64 = @'
IiIiDQpQYXJ0IFAtMDY0IFNURVAgMSDigJQgU2VhcmNoIHF1ZXJ5L21lcmdlIHNlcnZpY2UuDQoNCkFyY2hpdGVjdHVyZSBydWxl
cw0KLS0tLS0tLS0tLS0tLS0tLS0tDQotIFByb2R1Y3QgaXMgcmVhZCB0aHJvdWdoIGBQcm9kdWN0Lm9iamVjdHNgIG9ubHkgKFNv
ZnREZWxldGVNb2RlbCdzDQogIG1hbmFnZXIgYWxyZWFkeSBleGNsdWRlcyBzb2Z0LWRlbGV0ZWQgcm93cyksIGZ1cnRoZXIgbmFy
cm93ZWQgdG8NCiAgYGlzX2FjdGl2ZT1UcnVlYCDigJQgdGhlIGV4YWN0IHNhbWUgcHVibGljLXZpc2liaWxpdHkgcnVsZQ0KICBQ
cm9kdWN0UHVibGljTGlzdFZpZXcgKFAtMDMyKSBhbHJlYWR5IHVzZXMuIFByb2R1Y3QgaXMgTk9UIGENCiAgTW9kZXJhdGFibGUg
Y29udGVudCB0eXBlIChzZWUgcHJvZHVjdHMvbW9kZWxzLnB5KSwgc28gdGhlcmUgaXMgbm8NCiAgYHB1Ymxpc2hlZF9vYmplY3Rz
YC1zdHlsZSBtYW5hZ2VyIHRvIHJvdXRlIHRocm91Z2ggaGVyZS4NCi0gQnVzaW5lc3NQcm9maWxlIGlzIHJlYWQgdGhyb3VnaCBg
QnVzaW5lc3NQcm9maWxlLm9iamVjdHNgIG9ubHkNCiAgKHNhbWUgU29mdERlbGV0ZU1vZGVsIGV4Y2x1c2lvbikuIFRoZXJlIGlz
IGN1cnJlbnRseSBubyBzZXBhcmF0ZQ0KICAiYXBwcm92ZWQiLyJhY3RpdmUiIGdhdGUgb24gQnVzaW5lc3NQcm9maWxlIGJleW9u
ZCBzb2Z0LWRlbGV0ZSDigJQNCiAgY29uZmlybWVkIGRpcmVjdGx5IGFnYWluc3QgYnVzaW5lc3Nlcy9tb2RlbHMucHkgYmVmb3Jl
IHdyaXRpbmcgdGhpcywNCiAgcGVyIHRoaXMgcGFydCdzIG93biAiQkVGT1JFIENPRElORyIgaW5zdHJ1Y3Rpb24uDQotIGBQcm9k
dWN0YCBjYXJyaWVzIG5vIGBjb3VudHJ5YC9gY2l0eWAgb2YgaXRzIG93biAoY29uZmlybWVkIGFnYWluc3QNCiAgcHJvZHVjdHMv
bW9kZWxzLnB5IOKAlCBjb250cmFyeSB0byB0aGUgb3JpZ2luYWwgcGFydCB0ZXh0J3MNCiAgYXNzdW1wdGlvbiwgYW5kIGV4cGxp
Y2l0bHkgZmxhZ2dlZCBhcyBhIGNhcnJ5LWZvcndhcmQgbm90ZSBhdCB0aGUNCiAgZW5kIG9mIFAtMTA5J3MgcHJvZ3Jlc3MgZW50
cnkpLiBUaG9zZSB0d28gZmlsdGVycyByZWFjaCBQcm9kdWN0IG9ubHkNCiAgdGhyb3VnaCBgYnVzaW5lc3NfX2NvdW50cnlgIC8g
YGJ1c2luZXNzX19jaXR5YC4NCi0gYGNhdGVnb3J5YCBmaWx0ZXJzIEJPVEggQnVzaW5lc3NQcm9maWxlIGFuZCBQcm9kdWN0IChy
ZXZpc2VkIGluDQogIFNURVAgMiDigJQgc2VlIGJ1aWxkX2J1c2luZXNzX3F1ZXJ5c2V0KCkncyBvd24gZG9jc3RyaW5nIGZvciB3
aHkgdGhlDQogIG9yaWdpbmFsICJQcm9kdWN0LW9ubHkiIHJlYWRpbmcgd2FzIHJldmVyc2VkKS4NCi0gYG1pbl9wcmljZWAvYG1h
eF9wcmljZWAgZmlsdGVyIGBQcm9kdWN0LnByaWNlYCBvbmx5LCBhbmQgYXJlIG5ldmVyDQogIG5hbWVkIG9yIGRvY3VtZW50ZWQg
YW55d2hlcmUgYXMgYW55dGhpbmcgcmVzZW1ibGluZyBhIHRyYW5zYWN0aW9uYWwNCiAgcmFuZ2UgKFNlY3Rpb24gMjAgLyBQLTAz
MSdzIG93biBjb252ZW50aW9uKS4NCg0KTWVyZ2Ugc3RyYXRlZ3kgYW5kIGl0cyB0cmFkZS1vZmYgKE1WUCwgZG9jdW1lbnRlZCBv
biBwdXJwb3NlIOKAlA0Kc2FtZSB0cmFkZS1vZmYgZmVlZC9zZXJ2aWNlcy5weSBhbHJlYWR5IGFjY2VwdGVkIGZvciBQb3N0K1Jl
ZWwpDQotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQ0KQnVz
aW5lc3NQcm9maWxlIGFuZCBQcm9kdWN0IGxpdmUgaW4gZGlmZmVyZW50IHRhYmxlcywgc28gb25lIE9STQ0KcXVlcnlzZXQgY2Fu
bm90IG9yZGVyIHRoZW0gdG9nZXRoZXIuIEZvciBlYWNoIHJlcXVlc3Qgd2UgZmV0Y2ggYXQNCm1vc3QgYHBhZ2Vfc2l6ZWAgcm93
cyBmcm9tIEVBQ0ggbW9kZWwgKGFscmVhZHkgaW4gdGhhdCBtb2RlbCdzIG93bg0KdG90YWwgb3JkZXIpLCBtZXJnZSB0aGVtIGlu
IFB5dGhvbiBhbmQga2VlcCB0aGUgZmlyc3QgYHBhZ2Vfc2l6ZWAuDQpUaGlzIGlzIGV4YWN0LCBub3QgYXBwcm94aW1hdGU6IHRv
IGdldCB0aGUgdG9wLWsgb2YgdGhlIHVuaW9uIG9mIHR3bw0KYWxyZWFkeS1zb3J0ZWQgc3RyZWFtcywgbm8gc3RyZWFtIGNhbiBj
b250cmlidXRlIG1vcmUgdGhhbiBrIGl0ZW1zIHRvDQp0aGF0IHRvcC1rIOKAlCBzbyBmZXRjaGluZyBgcGFnZV9zaXplYCBmcm9t
IGVhY2ggaXMgYWx3YXlzIGVub3VnaCwNCndoZXRoZXIgcmVzdW1pbmcgZnJvbSB0aGUgdG9wIG9yIGZyb20gYSBjdXJzb3IuIFRo
ZSBjb3N0IGlzIHVwIHRvDQoyIHggcGFnZV9zaXplIHJvd3MgcmVhZCBwZXIgcmVxdWVzdCwgbWF0Y2hpbmcgZmVlZCdzIG93biBh
Y2NlcHRlZA0KU3RhZ2UtMSB0cmFkZS1vZmYgKGFyY2hpdGVjdHVyZSBTZWN0aW9uIDIpLg0KDQpPcmRlcmluZyBpcyBhIFRPVEFM
IG9yZGVyIGluIGJvdGggbW9kZXMsIHNvIGEgY3Vyc29yIGNhbiBuZXZlciBsYW5kIGluDQphbiBhbWJpZ3VvdXMgc3BvdDoNCg0K
ICAgIHJlbGV2YW5jZSBtb2RlIChxIGdpdmVuKTogIChpc19mZWF0dXJlZCwgcmFuaywgY29udGVudC10eXBlIHJhbmssIGlkKSwg
YWxsIGRlc2NlbmRpbmcNCiAgICByZWNlbmN5IG1vZGUgICAobm8gcSk6ICAgICAoaXNfZmVhdHVyZWQsIGNyZWF0ZWRfYXQsIGNv
bnRlbnQtdHlwZSByYW5rLCBpZCksIGFsbCBkZXNjZW5kaW5nDQoNCk5vIGNhY2hpbmcgKGRlbGliZXJhdGVseSwgdW5saWtlIEZl
ZWQpDQotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0NCkZlZWQncyBvd24gUC0wNjAgYWRkZWQgUmVkaXMg
Y2FjaGluZyBiZWNhdXNlIHRoZSBIb21lIEZlZWQgaXMgdGhlIHNhbWUNCmV4cGVuc2l2ZSBxdWVyeSByZXBlYXRlZCBmb3IgdGhl
IHNhbWUgdXNlciB2ZXJ5IGZyZXF1ZW50bHkuIFNlYXJjaA0KcmVxdWVzdHMgYXJlIGhpZ2hseSBwYXJhbWV0ZXItZGVwZW5kZW50
IChhcmJpdHJhcnkgcS9maWx0ZXINCmNvbWJpbmF0aW9ucyBwZXIgcmVxdWVzdCkgYW5kIGFscmVhZHkgc2VydmVkIG9mZiB0d28g
R0lOIGZ1bGwtdGV4dA0KaW5kZXhlcyAoUC0wNjMpIHBsdXMgdGhpcyBwYXJ0J3Mgb3duIGZpbHRlciBjb2x1bW5zLCBzbyBhIGNh
Y2hlIGhlcmUNCndvdWxkIGhhdmUgYSBsb3cgaGl0IHJhdGUgZm9yIHJlYWwgYWRkZWQgY29tcGxleGl0eS4gRmxhZ2dlZCBwZXIg
dGhpcw0KcGFydCdzIG93biAiZmxhZyByYXRoZXIgdGhhbiBzaWxlbnRseSBhZGQvb21pdCIgaW5zdHJ1Y3Rpb24g4oCUIHJldmlz
aXQNCmlmIHJlYWwgdXNhZ2UgZGF0YSBzYXlzIG90aGVyd2lzZS4NCiIiIg0KDQppbXBvcnQgcmUNCmZyb20gZGF0YWNsYXNzZXMg
aW1wb3J0IGRhdGFjbGFzcw0KZnJvbSBkZWNpbWFsIGltcG9ydCBEZWNpbWFsDQpmcm9tIGZ1bmN0b29scyBpbXBvcnQgcmVkdWNl
DQpmcm9tIG9wZXJhdG9yIGltcG9ydCBhbmRfDQpmcm9tIHR5cGluZyBpbXBvcnQgQW55LCBPcHRpb25hbA0KDQpmcm9tIGRqYW5n
by5jb250cmliLnBvc3RncmVzLnNlYXJjaCBpbXBvcnQgU2VhcmNoUXVlcnksIFNlYXJjaFJhbmsNCmZyb20gZGphbmdvLmRiLm1v
ZGVscyBpbXBvcnQgRiwgRmxvYXRGaWVsZCwgUSwgUXVlcnlTZXQsIFZhbHVlDQpmcm9tIGRqYW5nby5kYi5tb2RlbHMuZnVuY3Rp
b25zIGltcG9ydCBDYXN0LCBDb2FsZXNjZQ0KDQpmcm9tIGJ1c2luZXNzZXMubW9kZWxzIGltcG9ydCBCdXNpbmVzc1Byb2ZpbGUN
CmZyb20gcHJvZHVjdHMubW9kZWxzIGltcG9ydCBQcm9kdWN0DQoNCmZyb20gc2VhcmNoLmN1cnNvciBpbXBvcnQgKA0KICAgIENP
TlRFTlRfVFlQRV9CVVNJTkVTUywNCiAgICBDT05URU5UX1RZUEVfUFJPRFVDVCwNCiAgICBDT05URU5UX1RZUEVfUkFOSywNCiAg
ICBNT0RFX1JFQ0VOQ1ksDQogICAgTU9ERV9SRUxFVkFOQ0UsDQogICAgU2VhcmNoQ3Vyc29yLA0KICAgIGRlY29kZV9jdXJzb3Is
DQogICAgZW5jb2RlX2N1cnNvciwNCikNCg0KREVGQVVMVF9QQUdFX1NJWkUgPSAyMA0KTUFYX1BBR0VfU0laRSA9IDUwDQoNCiMg
TGV0dGVycy9kaWdpdHMgb2YgQU5ZIHNjcmlwdCAoQXJhYmljIGluY2x1ZGVkKTsgZXZlcnl0aGluZyBlbHNlDQojIChwdW5jdHVh
dGlvbiwgdHNxdWVyeSBvcGVyYXRvcnMgc3VjaCBhcyAmIHwgISAoICkgOiAnIFxcKSBpcyBkcm9wcGVkLCBzbw0KIyBhIHRva2Vu
IGlzIGFsd2F5cyBzYWZlIHRvIHNwbGljZSBpbnRvIGEgcmF3IHRzcXVlcnkuDQpfVE9LRU5fUkUgPSByZS5jb21waWxlKHIiW15c
V19dKyIsIHJlLlVOSUNPREUpDQoNCg0KZGVmIF90b2tlbml6ZSh0ZXh0OiBzdHIpIC0+IGxpc3Q6DQogICAgcmV0dXJuIF9UT0tF
Tl9SRS5maW5kYWxsKHRleHQpDQoNCg0KZGVmIF9idWlsZF9zZWFyY2hfcXVlcnkodGV4dDogc3RyKSAtPiBTZWFyY2hRdWVyeToN
CiAgICAiIiJXaG9sZS13b3JkIGZ1bGwtdGV4dCBxdWVyeSBPUidlZCB3aXRoIGEgcHJlZml4IHF1ZXJ5Lg0KDQogICAgUG9zdGdy
ZXMgZnVsbC10ZXh0IG9ubHkgbWF0Y2hlcyBXSE9MRSB3b3Jkcywgc28gd2hpbGUgdGhlIHVzZXIgaXMNCiAgICBzdGlsbCB0eXBp
bmcgKCJsZWF0IikgYFNlYXJjaFF1ZXJ5KCJsZWF0IilgIG1hdGNoZXMgbm90aGluZy4NCiAgICBUaGUgZXh0cmEgYHRvazoqYCB0
ZXJtcyBtYWtlIGV2ZXJ5IHRva2VuIGEgcHJlZml4IG1hdGNoLCB3aGljaCBpcw0KICAgIHdoYXQgYSBzZWFyY2gtYXMteW91LXR5
cGUgYm94IG5lZWRzLiBDb25maWcgaXMgdGhlIERCIGRlZmF1bHQgZm9yDQogICAgYm90aCBzaWRlcywgc2FtZSBhcyB0aGUgc3Rv
cmVkIGBzZWFyY2hfdmVjdG9yYC4NCiAgICAiIiINCiAgICBxdWVyeSA9IFNlYXJjaFF1ZXJ5KHRleHQpDQogICAgdG9rZW5zID0g
X3Rva2VuaXplKHRleHQpDQogICAgaWYgdG9rZW5zOg0KICAgICAgICBwcmVmaXggPSAiICYgIi5qb2luKGYie3Rva2VufToqIiBm
b3IgdG9rZW4gaW4gdG9rZW5zKQ0KICAgICAgICBxdWVyeSA9IHF1ZXJ5IHwgU2VhcmNoUXVlcnkocHJlZml4LCBzZWFyY2hfdHlw
ZT0icmF3IikNCiAgICByZXR1cm4gcXVlcnkNCg0KDQpkZWYgX2NvbnRhaW5zX2V2ZXJ5X3Rva2VuKHRleHQ6IHN0ciwgZmllbGRz
OiB0dXBsZSkgLT4gUToNCiAgICAiIiJDYXNlLWluc2Vuc2l0aXZlIHN1YnN0cmluZyBmYWxsYmFjazogZXZlcnkgdG9rZW4gbXVz
dCBhcHBlYXIgaW4NCiAgICBhdCBsZWFzdCBvbmUgb2YgYGZpZWxkc2AuIFdvcmtzIGZvciBwYXJ0aWFsIHdvcmRzLCBBcmFiaWMg
dGV4dCBhbmQNCiAgICByb3dzIHdob3NlIGBzZWFyY2hfdmVjdG9yYCBpcyBOVUxMIC8gc3RhbGUuIiIiDQogICAgdG9rZW5zID0g
X3Rva2VuaXplKHRleHQpIG9yIFt0ZXh0XQ0KICAgIHBlcl90b2tlbiA9IFtdDQogICAgZm9yIHRva2VuIGluIHRva2VuczoNCiAg
ICAgICAgYW55X2ZpZWxkID0gUSgpDQogICAgICAgIGZvciBmaWVsZCBpbiBmaWVsZHM6DQogICAgICAgICAgICBhbnlfZmllbGQg
fD0gUSgqKntmIntmaWVsZH1fX2ljb250YWlucyI6IHRva2VufSkNCiAgICAgICAgcGVyX3Rva2VuLmFwcGVuZChhbnlfZmllbGQp
DQogICAgcmV0dXJuIHJlZHVjZShhbmRfLCBwZXJfdG9rZW4pDQoNCg0KZGVmIF9yYW5rX2V4cHJlc3Npb24oc2VhcmNoX3F1ZXJ5
KSAtPiBDb2FsZXNjZToNCiAgICAiIiJTZWFyY2hSYW5rIGFzIGZsb2F0OCwgTlVMTCAobm8gc2VhcmNoX3ZlY3RvcikgLT4gMC4N
Cg0KICAgIFRoZSBleHBsaWNpdCBDYXN0IG1hdHRlcnMgZm9yIHBhZ2luYXRpb246IHRzX3JhbmsgcmV0dXJucyBgcmVhbGANCiAg
ICAoZmxvYXQ0KSwgd2hvc2UgdmFsdWUgZG9lcyBub3Qgcm91bmQtdHJpcCB0aHJvdWdoIHRoZSBjdXJzb3Incw0KICAgIFB5dGhv
biBmbG9hdCwgc28gYHJhbmsgPSA8Y3Vyc29yIHZhbHVlPmAgbmV2ZXIgbWF0Y2hlZCBhbmQgZXZlcnkNCiAgICBwYWdlIGFmdGVy
IHRoZSBmaXJzdCBjYW1lIGJhY2sgZW1wdHkgd2hlbmV2ZXIgc2V2ZXJhbCByZXN1bHRzDQogICAgc2hhcmVkIHRoZSBzYW1lIHJh
bmsuIGZsb2F0OCByb3VuZC10cmlwcyBleGFjdGx5Lg0KICAgICIiIg0KICAgIHJldHVybiBDb2FsZXNjZSgNCiAgICAgICAgQ2Fz
dChTZWFyY2hSYW5rKEYoInNlYXJjaF92ZWN0b3IiKSwgc2VhcmNoX3F1ZXJ5KSwgRmxvYXRGaWVsZCgpKSwNCiAgICAgICAgVmFs
dWUoMC4wKSwNCiAgICAgICAgb3V0cHV0X2ZpZWxkPUZsb2F0RmllbGQoKSwNCiAgICApDQoNCg0KQGRhdGFjbGFzcyhmcm96ZW49
VHJ1ZSkNCmNsYXNzIFNlYXJjaEZpbHRlcnM6DQogICAgIiIiQWxyZWFkeS1wYXJzZWQgZmlsdGVyIHZhbHVlcy4gVGhlIHZpZXcg
KFNURVAgMikgaXMgdGhlIGxheWVyDQogICAgdGhhdCB0dXJucyByYXcgcXVlcnkgcGFyYW1zIGludG8gdGhpcyDigJQgbm90aGlu
ZyBoZXJlIGV2ZXIgdG91Y2hlcw0KICAgIHJlcXVlc3QuR0VUIGRpcmVjdGx5LCBzbyB0aGlzIG1vZHVsZSBzdGF5cyBpbmRlcGVu
ZGVudGx5IHRlc3RhYmxlLg0KICAgICIiIg0KDQogICAgY2F0ZWdvcnlfaWQ6IE9wdGlvbmFsW2ludF0gPSBOb25lDQogICAgY291
bnRyeTogT3B0aW9uYWxbc3RyXSA9IE5vbmUNCiAgICBjaXR5OiBPcHRpb25hbFtzdHJdID0gTm9uZQ0KICAgIGJ1c2luZXNzX3R5
cGU6IE9wdGlvbmFsW3N0cl0gPSBOb25lDQogICAgbWluX3JhdGluZzogT3B0aW9uYWxbRGVjaW1hbF0gPSBOb25lDQogICAgZmVh
dHVyZWRfb25seTogYm9vbCA9IEZhbHNlDQogICAgbWluX3ByaWNlOiBPcHRpb25hbFtEZWNpbWFsXSA9IE5vbmUNCiAgICBtYXhf
cHJpY2U6IE9wdGlvbmFsW0RlY2ltYWxdID0gTm9uZQ0KDQoNCkBkYXRhY2xhc3MoZnJvemVuPVRydWUpDQpjbGFzcyBTZWFyY2hS
ZXN1bHQ6DQogICAgIiIiT25lIG1lcmdlZCByZXN1bHQ6IGEgQnVzaW5lc3NQcm9maWxlIG9yIGEgUHJvZHVjdCwgdGFnZ2VkIHdp
dGgNCiAgICBpdHMgcmVzdWx0X3R5cGUgYW5kIHRoZSB0d28gdmFsdWVzIHRoZSB0b3RhbCBvcmRlciBzb3J0cyBvbi4iIiINCg0K
ICAgIGNvbnRlbnRfdHlwZTogc3RyICAjICJidXNpbmVzcyIgfCAicHJvZHVjdCINCiAgICBvYmo6IEFueQ0KICAgIGlzX2ZlYXR1
cmVkOiBib29sDQogICAgc2Vjb25kYXJ5OiBBbnkgICMgZmxvYXQgKHJlbGV2YW5jZSBtb2RlKSBvciBkYXRldGltZSAocmVjZW5j
eSBtb2RlKQ0KDQogICAgQHByb3BlcnR5DQogICAgZGVmIGlkKHNlbGYpIC0+IGludDoNCiAgICAgICAgcmV0dXJuIHNlbGYub2Jq
LnBrDQoNCiAgICBkZWYgdG9fY3Vyc29yKHNlbGYsIG1vZGU6IHN0cikgLT4gU2VhcmNoQ3Vyc29yOg0KICAgICAgICByZXR1cm4g
U2VhcmNoQ3Vyc29yKA0KICAgICAgICAgICAgbW9kZT1tb2RlLA0KICAgICAgICAgICAgaXNfZmVhdHVyZWQ9c2VsZi5pc19mZWF0
dXJlZCwNCiAgICAgICAgICAgIHNlY29uZGFyeT1zZWxmLnNlY29uZGFyeSwNCiAgICAgICAgICAgIGNvbnRlbnRfdHlwZT1zZWxm
LmNvbnRlbnRfdHlwZSwNCiAgICAgICAgICAgIG9iamVjdF9pZD1zZWxmLmlkLA0KICAgICAgICApDQoNCg0KZGVmIF9zb3J0X2tl
eShlbnRyeTogU2VhcmNoUmVzdWx0KToNCiAgICAiIiJUb3RhbCBvcmRlciBvZiB0aGUgbWVyZ2VkIGxpc3QgKHNvcnQgd2l0aCBy
ZXZlcnNlPVRydWUpLiIiIg0KICAgIHJldHVybiAoDQogICAgICAgIGVudHJ5LmlzX2ZlYXR1cmVkLA0KICAgICAgICBlbnRyeS5z
ZWNvbmRhcnksDQogICAgICAgIENPTlRFTlRfVFlQRV9SQU5LW2VudHJ5LmNvbnRlbnRfdHlwZV0sDQogICAgICAgIGVudHJ5Lmlk
LA0KICAgICkNCg0KDQpkZWYgX3Jvd3NfYWZ0ZXIoaXNfZmVhdHVyZWRfZmllbGQ6IHN0ciwgc2Vjb25kYXJ5X2ZpZWxkOiBzdHIs
ICosIGNvbnRlbnRfdHlwZTogc3RyLCBjdXJzb3I6IFNlYXJjaEN1cnNvcikgLT4gUToNCiAgICAiIiINCiAgICBSb3dzIG9mIGBj
b250ZW50X3R5cGVgIHRoYXQgY29tZSBzdHJpY3RseSBBRlRFUiBgY3Vyc29yYCBpbiB0aGUNCiAgICBkZXNjZW5kaW5nIChpc19m
ZWF0dXJlZCwgc2Vjb25kYXJ5LCBjb250ZW50LXR5cGUgcmFuaywgaWQpIG9yZGVyIOKAlA0KICAgIHNhbWUgY29uc3RydWN0aW9u
IGFzIGZlZWQvc2VydmljZXMucHkncyBgX2JhY2tmaWxsX3Jvd3NfYWZ0ZXJgLA0KICAgIGdlbmVyYWxpc2VkIHNvIGBzZWNvbmRh
cnlfZmllbGRgIGNhbiBiZSBhbiBhbm5vdGF0ZWQgcmFuayBPUiBhDQogICAgcGxhaW4gYGNyZWF0ZWRfYXRgLCBhbmQgYGlzX2Zl
YXR1cmVkX2ZpZWxkYCBjYW4gYmUgYSBkaXJlY3QgZmllbGQNCiAgICAoQnVzaW5lc3NQcm9maWxlLmlzX2ZlYXR1cmVkKSBvciBh
IGpvaW4gKFByb2R1Y3QuYnVzaW5lc3NfX2lzX2ZlYXR1cmVkKS4NCiAgICAiIiINCiAgICByYW5rID0gQ09OVEVOVF9UWVBFX1JB
TktbY29udGVudF90eXBlXQ0KICAgIGN1cnNvcl9yYW5rID0gQ09OVEVOVF9UWVBFX1JBTktbY3Vyc29yLmNvbnRlbnRfdHlwZV0N
CiAgICBpZiByYW5rIDwgY3Vyc29yX3Jhbms6DQogICAgICAgIHNhbWVfc2Vjb25kYXJ5X3RpZWJyZWFrID0gUSgqKntmIntzZWNv
bmRhcnlfZmllbGR9X19sdGUiOiBjdXJzb3Iuc2Vjb25kYXJ5fSkNCiAgICBlbGlmIHJhbmsgPiBjdXJzb3JfcmFuazoNCiAgICAg
ICAgc2FtZV9zZWNvbmRhcnlfdGllYnJlYWsgPSBRKCoqe2Yie3NlY29uZGFyeV9maWVsZH1fX2x0IjogY3Vyc29yLnNlY29uZGFy
eX0pDQogICAgZWxzZToNCiAgICAgICAgc2FtZV9zZWNvbmRhcnlfdGllYnJlYWsgPSBRKCoqe2Yie3NlY29uZGFyeV9maWVsZH1f
X2x0IjogY3Vyc29yLnNlY29uZGFyeX0pIHwgUSgNCiAgICAgICAgICAgICoqe3NlY29uZGFyeV9maWVsZDogY3Vyc29yLnNlY29u
ZGFyeSwgImlkX19sdCI6IGN1cnNvci5vYmplY3RfaWR9DQogICAgICAgICkNCg0KICAgIGlmIGN1cnNvci5pc19mZWF0dXJlZDoN
CiAgICAgICAgcmV0dXJuIFEoKip7aXNfZmVhdHVyZWRfZmllbGQ6IEZhbHNlfSkgfCAoDQogICAgICAgICAgICBRKCoqe2lzX2Zl
YXR1cmVkX2ZpZWxkOiBUcnVlfSkgJiBzYW1lX3NlY29uZGFyeV90aWVicmVhaw0KICAgICAgICApDQogICAgcmV0dXJuIFEoKip7
aXNfZmVhdHVyZWRfZmllbGQ6IEZhbHNlfSkgJiBzYW1lX3NlY29uZGFyeV90aWVicmVhaw0KDQoNCmRlZiBidWlsZF9idXNpbmVz
c19xdWVyeXNldChmaWx0ZXJzOiBTZWFyY2hGaWx0ZXJzKSAtPiBRdWVyeVNldDoNCiAgICAiIiJCdXNpbmVzc1Byb2ZpbGUgcm93
cyBtYXRjaGluZyBldmVyeSBwcmVzZW50IGZpbHRlciB0aGF0IGFwcGxpZXMNCiAgICB0byBidXNpbmVzc2VzLiBgY2F0ZWdvcnlg
IERPRVMgYXBwbHkgaGVyZSAocmV2aXNlZCBkZWNpc2lvbiwgU1RFUA0KICAgIDIpOiBCdXNpbmVzc1Byb2ZpbGUgY2FycmllcyBp
dHMgb3duIGBjYXRlZ29yeWAgRksgKFAtMDI2KSBhbmQgbm8NCiAgICBsYXRlciBwYXJ0IGluIHRoZSBtYXN0ZXIgcGxhbiAoY2hl
Y2tlZCBQLTA2NSB0aHJvdWdoIFAtMDkzKSBldmVyDQogICAgYWRkcyBidXNpbmVzcy1zaWRlIGNhdGVnb3J5IGZpbHRlcmluZyB0
byBTZWFyY2gsIHNvIGxlYXZpbmcgaXQNCiAgICBvdXQgbm93IHdvdWxkIG1lYW4gaXQgbmV2ZXIgZ2V0cyBhZGRlZCBhdCBhbGwg
4oCUIHNlZSB0aGlzIHBhcnQncw0KICAgIG93biBoYW5kb2ZmIG5vdGUuIiIiDQogICAgcXMgPSBCdXNpbmVzc1Byb2ZpbGUub2Jq
ZWN0cy5hbGwoKQ0KICAgIGlmIGZpbHRlcnMuY2F0ZWdvcnlfaWQgaXMgbm90IE5vbmU6DQogICAgICAgIHFzID0gcXMuZmlsdGVy
KGNhdGVnb3J5X2lkPWZpbHRlcnMuY2F0ZWdvcnlfaWQpDQogICAgaWYgZmlsdGVycy5jb3VudHJ5Og0KICAgICAgICBxcyA9IHFz
LmZpbHRlcihjb3VudHJ5PWZpbHRlcnMuY291bnRyeSkNCiAgICBpZiBmaWx0ZXJzLmNpdHk6DQogICAgICAgIHFzID0gcXMuZmls
dGVyKGNpdHk9ZmlsdGVycy5jaXR5KQ0KICAgIGlmIGZpbHRlcnMuYnVzaW5lc3NfdHlwZToNCiAgICAgICAgcXMgPSBxcy5maWx0
ZXIoYnVzaW5lc3NfdHlwZT1maWx0ZXJzLmJ1c2luZXNzX3R5cGUpDQogICAgaWYgZmlsdGVycy5taW5fcmF0aW5nIGlzIG5vdCBO
b25lOg0KICAgICAgICBxcyA9IHFzLmZpbHRlcihhdmVyYWdlX3JhdGluZ19fZ3RlPWZpbHRlcnMubWluX3JhdGluZykNCiAgICBp
ZiBmaWx0ZXJzLmZlYXR1cmVkX29ubHk6DQogICAgICAgIHFzID0gcXMuZmlsdGVyKGlzX2ZlYXR1cmVkPVRydWUpDQogICAgcmV0
dXJuIHFzDQoNCg0KZGVmIGJ1aWxkX3Byb2R1Y3RfcXVlcnlzZXQoZmlsdGVyczogU2VhcmNoRmlsdGVycykgLT4gUXVlcnlTZXQ6
DQogICAgIiIiUHJvZHVjdCByb3dzIG1hdGNoaW5nIGV2ZXJ5IHByZXNlbnQgZmlsdGVyIHRoYXQgYXBwbGllcyB0bw0KICAgIHBy
b2R1Y3RzLiBgY291bnRyeWAvYGNpdHlgIGpvaW4gdGhyb3VnaCBgYnVzaW5lc3NfXy4uLmAgc2luY2UNCiAgICBQcm9kdWN0IGhh
cyBubyBzdWNoIGZpZWxkcyBvZiBpdHMgb3duLiIiIg0KICAgIHFzID0gUHJvZHVjdC5vYmplY3RzLmZpbHRlcihpc19hY3RpdmU9
VHJ1ZSkNCiAgICBpZiBmaWx0ZXJzLmNhdGVnb3J5X2lkIGlzIG5vdCBOb25lOg0KICAgICAgICBxcyA9IHFzLmZpbHRlcihjYXRl
Z29yeV9pZD1maWx0ZXJzLmNhdGVnb3J5X2lkKQ0KICAgIGlmIGZpbHRlcnMuY291bnRyeToNCiAgICAgICAgcXMgPSBxcy5maWx0
ZXIoYnVzaW5lc3NfX2NvdW50cnk9ZmlsdGVycy5jb3VudHJ5KQ0KICAgIGlmIGZpbHRlcnMuY2l0eToNCiAgICAgICAgcXMgPSBx
cy5maWx0ZXIoYnVzaW5lc3NfX2NpdHk9ZmlsdGVycy5jaXR5KQ0KICAgIGlmIGZpbHRlcnMubWluX3ByaWNlIGlzIG5vdCBOb25l
Og0KICAgICAgICBxcyA9IHFzLmZpbHRlcihwcmljZV9fZ3RlPWZpbHRlcnMubWluX3ByaWNlKQ0KICAgIGlmIGZpbHRlcnMubWF4
X3ByaWNlIGlzIG5vdCBOb25lOg0KICAgICAgICBxcyA9IHFzLmZpbHRlcihwcmljZV9fbHRlPWZpbHRlcnMubWF4X3ByaWNlKQ0K
ICAgIGlmIGZpbHRlcnMuZmVhdHVyZWRfb25seToNCiAgICAgICAgcXMgPSBxcy5maWx0ZXIoYnVzaW5lc3NfX2lzX2ZlYXR1cmVk
PVRydWUpDQogICAgcmV0dXJuIHFzDQoNCg0KZGVmIF9mZXRjaF9idXNpbmVzc19lbnRyaWVzKA0KICAgIGZpbHRlcnMsICosIHNl
YXJjaF9xdWVyeSwgbW9kZSwgY3Vyc29yLCBsaW1pdCwgdGV4dD1Ob25lDQopOg0KICAgIGlmIGxpbWl0IDw9IDA6DQogICAgICAg
IHJldHVybiBbXQ0KICAgIHFzID0gYnVpbGRfYnVzaW5lc3NfcXVlcnlzZXQoZmlsdGVycykNCiAgICBpZiBzZWFyY2hfcXVlcnkg
aXMgbm90IE5vbmU6DQogICAgICAgIHFzID0gcXMuZmlsdGVyKA0KICAgICAgICAgICAgUShzZWFyY2hfdmVjdG9yPXNlYXJjaF9x
dWVyeSkNCiAgICAgICAgICAgIHwgX2NvbnRhaW5zX2V2ZXJ5X3Rva2VuKHRleHQgb3IgIiIsICgiYnVzaW5lc3NfbmFtZSIsICJk
ZXNjcmlwdGlvbiIpKQ0KICAgICAgICApLmFubm90YXRlKHJhbms9X3JhbmtfZXhwcmVzc2lvbihzZWFyY2hfcXVlcnkpKQ0KICAg
ICAgICBxcyA9IHFzLm9yZGVyX2J5KCItaXNfZmVhdHVyZWQiLCAiLXJhbmsiLCAiLWlkIikNCiAgICAgICAgc2Vjb25kYXJ5X2Zp
ZWxkID0gInJhbmsiDQogICAgZWxzZToNCiAgICAgICAgcXMgPSBxcy5vcmRlcl9ieSgiLWlzX2ZlYXR1cmVkIiwgIi1jcmVhdGVk
X2F0IiwgIi1pZCIpDQogICAgICAgIHNlY29uZGFyeV9maWVsZCA9ICJjcmVhdGVkX2F0Ig0KDQogICAgaWYgY3Vyc29yIGlzIG5v
dCBOb25lOg0KICAgICAgICBxcyA9IHFzLmZpbHRlcigNCiAgICAgICAgICAgIF9yb3dzX2FmdGVyKA0KICAgICAgICAgICAgICAg
ICJpc19mZWF0dXJlZCIsDQogICAgICAgICAgICAgICAgc2Vjb25kYXJ5X2ZpZWxkLA0KICAgICAgICAgICAgICAgIGNvbnRlbnRf
dHlwZT1DT05URU5UX1RZUEVfQlVTSU5FU1MsDQogICAgICAgICAgICAgICAgY3Vyc29yPWN1cnNvciwNCiAgICAgICAgICAgICkN
CiAgICAgICAgKQ0KDQogICAgZW50cmllcyA9IFtdDQogICAgZm9yIG9iaiBpbiBxc1s6bGltaXRdOg0KICAgICAgICBzZWNvbmRh
cnkgPSBvYmoucmFuayBpZiBtb2RlID09IE1PREVfUkVMRVZBTkNFIGVsc2Ugb2JqLmNyZWF0ZWRfYXQNCiAgICAgICAgZW50cmll
cy5hcHBlbmQoDQogICAgICAgICAgICBTZWFyY2hSZXN1bHQoDQogICAgICAgICAgICAgICAgY29udGVudF90eXBlPUNPTlRFTlRf
VFlQRV9CVVNJTkVTUywNCiAgICAgICAgICAgICAgICBvYmo9b2JqLA0KICAgICAgICAgICAgICAgIGlzX2ZlYXR1cmVkPW9iai5p
c19mZWF0dXJlZCwNCiAgICAgICAgICAgICAgICBzZWNvbmRhcnk9c2Vjb25kYXJ5LA0KICAgICAgICAgICAgKQ0KICAgICAgICAp
DQogICAgcmV0dXJuIGVudHJpZXMNCg0KDQpkZWYgX2ZldGNoX3Byb2R1Y3RfZW50cmllcygNCiAgICBmaWx0ZXJzLCAqLCBzZWFy
Y2hfcXVlcnksIG1vZGUsIGN1cnNvciwgbGltaXQsIHRleHQ9Tm9uZQ0KKToNCiAgICBpZiBsaW1pdCA8PSAwOg0KICAgICAgICBy
ZXR1cm4gW10NCiAgICBxcyA9IGJ1aWxkX3Byb2R1Y3RfcXVlcnlzZXQoZmlsdGVycykNCiAgICBpZiBzZWFyY2hfcXVlcnkgaXMg
bm90IE5vbmU6DQogICAgICAgIHFzID0gcXMuZmlsdGVyKA0KICAgICAgICAgICAgUShzZWFyY2hfdmVjdG9yPXNlYXJjaF9xdWVy
eSkNCiAgICAgICAgICAgIHwgX2NvbnRhaW5zX2V2ZXJ5X3Rva2VuKHRleHQgb3IgIiIsICgibmFtZSIsICJkZXNjcmlwdGlvbiIp
KQ0KICAgICAgICApLmFubm90YXRlKHJhbms9X3JhbmtfZXhwcmVzc2lvbihzZWFyY2hfcXVlcnkpKQ0KICAgICAgICBxcyA9IHFz
Lm9yZGVyX2J5KCItYnVzaW5lc3NfX2lzX2ZlYXR1cmVkIiwgIi1yYW5rIiwgIi1pZCIpDQogICAgICAgIHNlY29uZGFyeV9maWVs
ZCA9ICJyYW5rIg0KICAgIGVsc2U6DQogICAgICAgIHFzID0gcXMub3JkZXJfYnkoIi1idXNpbmVzc19faXNfZmVhdHVyZWQiLCAi
LWNyZWF0ZWRfYXQiLCAiLWlkIikNCiAgICAgICAgc2Vjb25kYXJ5X2ZpZWxkID0gImNyZWF0ZWRfYXQiDQoNCiAgICBpZiBjdXJz
b3IgaXMgbm90IE5vbmU6DQogICAgICAgIHFzID0gcXMuZmlsdGVyKA0KICAgICAgICAgICAgX3Jvd3NfYWZ0ZXIoDQogICAgICAg
ICAgICAgICAgImJ1c2luZXNzX19pc19mZWF0dXJlZCIsDQogICAgICAgICAgICAgICAgc2Vjb25kYXJ5X2ZpZWxkLA0KICAgICAg
ICAgICAgICAgIGNvbnRlbnRfdHlwZT1DT05URU5UX1RZUEVfUFJPRFVDVCwNCiAgICAgICAgICAgICAgICBjdXJzb3I9Y3Vyc29y
LA0KICAgICAgICAgICAgKQ0KICAgICAgICApDQoNCiAgICBxcyA9IHFzLnNlbGVjdF9yZWxhdGVkKCJidXNpbmVzcyIpDQogICAg
ZW50cmllcyA9IFtdDQogICAgZm9yIG9iaiBpbiBxc1s6bGltaXRdOg0KICAgICAgICBzZWNvbmRhcnkgPSBvYmoucmFuayBpZiBt
b2RlID09IE1PREVfUkVMRVZBTkNFIGVsc2Ugb2JqLmNyZWF0ZWRfYXQNCiAgICAgICAgZW50cmllcy5hcHBlbmQoDQogICAgICAg
ICAgICBTZWFyY2hSZXN1bHQoDQogICAgICAgICAgICAgICAgY29udGVudF90eXBlPUNPTlRFTlRfVFlQRV9QUk9EVUNULA0KICAg
ICAgICAgICAgICAgIG9iaj1vYmosDQogICAgICAgICAgICAgICAgaXNfZmVhdHVyZWQ9b2JqLmJ1c2luZXNzLmlzX2ZlYXR1cmVk
LA0KICAgICAgICAgICAgICAgIHNlY29uZGFyeT1zZWNvbmRhcnksDQogICAgICAgICAgICApDQogICAgICAgICkNCiAgICByZXR1
cm4gZW50cmllcw0KDQoNCmRlZiBnZXRfc2VhcmNoX3Jlc3VsdHMoDQogICAgZmlsdGVyczogU2VhcmNoRmlsdGVycywNCiAgICAq
LA0KICAgIHE6IE9wdGlvbmFsW3N0cl0gPSBOb25lLA0KICAgIGN1cnNvcjogT3B0aW9uYWxbc3RyXSA9IE5vbmUsDQogICAgcGFn
ZV9zaXplOiBpbnQgPSBERUZBVUxUX1BBR0VfU0laRSwNCikgLT4gZGljdDoNCiAgICAiIiINCiAgICBUaGUgbWVyZ2VkLCBwYWdp
bmF0ZWQgc2VhcmNoIHJlc3VsdCBzZXQuDQoNCiAgICBSZXR1cm5zIHsiaXRlbXMiOiBbU2VhcmNoUmVzdWx0LCAuLi5dLCAibmV4
dF9jdXJzb3IiOiBzdHJ8Tm9uZX0uDQoNCiAgICBSYWlzZXMgSW52YWxpZEN1cnNvckVycm9yIChhIFZhbHVlRXJyb3IpIGlmIGBj
dXJzb3JgIGlzIG1hbGZvcm1lZA0KICAgIG9yIHdhcyBpc3N1ZWQgaW4gdGhlIHdyb25nIG1vZGUsIGFuZCBWYWx1ZUVycm9yIGlm
IGBwYWdlX3NpemVgIGlzDQogICAgb3V0IG9mIHJhbmdlIOKAlCBib3RoIGFyZSBjYWxsZXIgaW5wdXQgZXJyb3JzIGZvciB0aGUg
dmlldyAoU1RFUCAyKQ0KICAgIHRvIHR1cm4gaW50byBhIDQwMCwgZXhhY3RseSBsaWtlIGZlZWQvc2VydmljZXMuZ2V0X2hvbWVf
ZmVlZCgpDQogICAgYWxyZWFkeSBkb2VzIGZvciBpdHMgb3duIGN1cnNvci4NCiAgICAiIiINCiAgICBpZiBub3QgaXNpbnN0YW5j
ZShwYWdlX3NpemUsIGludCkgb3IgcGFnZV9zaXplIDw9IDAgb3IgcGFnZV9zaXplID4gTUFYX1BBR0VfU0laRToNCiAgICAgICAg
cmFpc2UgVmFsdWVFcnJvcihmInBhZ2Vfc2l6ZSBtdXN0IGJlIGJldHdlZW4gMSBhbmQge01BWF9QQUdFX1NJWkV9IikNCg0KICAg
IG5vcm1hbGl6ZWRfcSA9IHEuc3RyaXAoKSBpZiBxIGVsc2UgIiINCiAgICBtb2RlID0gTU9ERV9SRUxFVkFOQ0UgaWYgbm9ybWFs
aXplZF9xIGVsc2UgTU9ERV9SRUNFTkNZDQogICAgc2VhcmNoX3F1ZXJ5ID0gX2J1aWxkX3NlYXJjaF9xdWVyeShub3JtYWxpemVk
X3EpIGlmIG5vcm1hbGl6ZWRfcSBlbHNlIE5vbmUNCg0KICAgIGRlY29kZWRfY3Vyc29yID0gZGVjb2RlX2N1cnNvcihjdXJzb3Is
IGV4cGVjdGVkX21vZGU9bW9kZSkgaWYgY3Vyc29yIGVsc2UgTm9uZQ0KDQogICAgYnVzaW5lc3NfZW50cmllcyA9IF9mZXRjaF9i
dXNpbmVzc19lbnRyaWVzKA0KICAgICAgICBmaWx0ZXJzLA0KICAgICAgICBzZWFyY2hfcXVlcnk9c2VhcmNoX3F1ZXJ5LA0KICAg
ICAgICB0ZXh0PW5vcm1hbGl6ZWRfcSwNCiAgICAgICAgbW9kZT1tb2RlLA0KICAgICAgICBjdXJzb3I9ZGVjb2RlZF9jdXJzb3Is
DQogICAgICAgIGxpbWl0PXBhZ2Vfc2l6ZSwNCiAgICApDQogICAgcHJvZHVjdF9lbnRyaWVzID0gX2ZldGNoX3Byb2R1Y3RfZW50
cmllcygNCiAgICAgICAgZmlsdGVycywNCiAgICAgICAgc2VhcmNoX3F1ZXJ5PXNlYXJjaF9xdWVyeSwNCiAgICAgICAgdGV4dD1u
b3JtYWxpemVkX3EsDQogICAgICAgIG1vZGU9bW9kZSwNCiAgICAgICAgY3Vyc29yPWRlY29kZWRfY3Vyc29yLA0KICAgICAgICBs
aW1pdD1wYWdlX3NpemUsDQogICAgKQ0KDQogICAgbWVyZ2VkID0gYnVzaW5lc3NfZW50cmllcyArIHByb2R1Y3RfZW50cmllcw0K
ICAgIG1lcmdlZC5zb3J0KGtleT1fc29ydF9rZXksIHJldmVyc2U9VHJ1ZSkNCiAgICBpdGVtcyA9IG1lcmdlZFs6cGFnZV9zaXpl
XQ0KDQogICAgbmV4dF9jdXJzb3IgPSBOb25lDQogICAgaWYgbGVuKGl0ZW1zKSA+PSBwYWdlX3NpemU6DQogICAgICAgIG5leHRf
Y3Vyc29yID0gZW5jb2RlX2N1cnNvcihpdGVtc1stMV0udG9fY3Vyc29yKG1vZGUpKQ0KDQogICAgcmV0dXJuIHsiaXRlbXMiOiBp
dGVtcywgIm5leHRfY3Vyc29yIjogbmV4dF9jdXJzb3J9
'@
    }
    @{
        Repo = 'app'
        Path = 'search/tests/test_partial_match.py'
        ExpectedHash = $null
        B64 = @'
IiIiDQpSZWdyZXNzaW9uIHRlc3RzIGZvciB0aGUgInNlYXJjaCBzaG93cyBub3RoaW5nIHdoaWxlIHR5cGluZyIgYnVnLg0KDQpC
ZWZvcmUgdGhlIGZpeCwgYHFgIHdhcyBtYXRjaGVkIE9OTFkgdGhyb3VnaCB0aGUgUG9zdGdyZXMgZnVsbC10ZXh0DQpgc2VhcmNo
X3ZlY3RvcmAgd2l0aCBhIHdob2xlLXdvcmQgYFNlYXJjaFF1ZXJ5YCwgc286DQoNCiAgKiBhIHBhcnRpYWwgd29yZCAod2hhdCB0
aGUgdXNlciBoYXMgdHlwZWQgc28gZmFyLCBlLmcuICJsZWF0IikgbmV2ZXINCiAgICBtYXRjaGVkICJMZWF0aGVyIiwgYW5kDQog
ICogYW55IHJvdyB3aG9zZSBgc2VhcmNoX3ZlY3RvcmAgd2FzIE5VTEwgKGNyZWF0ZWQgYmVmb3JlIHRoZSBzaWduYWwNCiAgICBl
eGlzdGVkLCBpbXBvcnRlZCBpbiBidWxrLCBvciBlZGl0ZWQgdGhyb3VnaCBgUXVlcnlTZXQudXBkYXRlKClgKQ0KICAgIGNvdWxk
IG5ldmVyIGJlIGZvdW5kIHdpdGggYSBxdWVyeSAtLSB5ZXQgaXQgd2FzIHJldHVybmVkIGZpbmUgd2hlbg0KICAgIGBxYCB3YXMg
ZW1wdHksIHdoaWNoIGlzIGV4YWN0bHkgdGhlIHN5bXB0b20gcmVwb3J0ZWQuDQoiIiINCg0KZnJvbSBkamFuZ28udXJscyBpbXBv
cnQgcmV2ZXJzZQ0KZnJvbSByZXN0X2ZyYW1ld29yayBpbXBvcnQgc3RhdHVzDQpmcm9tIHJlc3RfZnJhbWV3b3JrLnRlc3QgaW1w
b3J0IEFQSVRlc3RDYXNlDQoNCmZyb20gYnVzaW5lc3Nlcy5tb2RlbHMgaW1wb3J0IEJ1c2luZXNzUHJvZmlsZQ0KZnJvbSBwcm9k
dWN0cy5tb2RlbHMgaW1wb3J0IFByb2R1Y3QNCg0KZnJvbSBzZWFyY2gudGVzdHMudGVzdF9hcGkgaW1wb3J0ICgNCiAgICBtYWtl
X2J1c2luZXNzLA0KICAgIG1ha2VfY2F0ZWdvcnksDQogICAgbWFrZV9wcm9kdWN0LA0KICAgIF9uYW1lcywNCikNCg0KU0VBUkNI
X1VSTCA9IHJldmVyc2UoInNlYXJjaCIpDQoNCg0KY2xhc3MgVGVzdFBhcnRpYWxBbmROdWxsVmVjdG9yTWF0Y2hpbmcoQVBJVGVz
dENhc2UpOg0KICAgIGRlZiB0ZXN0X3BhcnRpYWxfd29yZF9tYXRjaGVzX2J1c2luZXNzX2FuZF9wcm9kdWN0KHNlbGYpOg0KICAg
ICAgICBjYXQgPSBtYWtlX2NhdGVnb3J5KCkNCiAgICAgICAgYml6ID0gbWFrZV9idXNpbmVzcygiTGVhdGhlciBXb3JsZCIpDQog
ICAgICAgIG1ha2VfcHJvZHVjdChiaXosIGNhdCwgIkxlYXRoZXIgQmFnIikNCg0KICAgICAgICByZXNwb25zZSA9IHNlbGYuY2xp
ZW50LmdldChTRUFSQ0hfVVJMLCB7InEiOiAibGVhdCJ9KQ0KDQogICAgICAgIGFzc2VydCByZXNwb25zZS5zdGF0dXNfY29kZSA9
PSBzdGF0dXMuSFRUUF8yMDBfT0sNCiAgICAgICAgbmFtZXMgPSBfbmFtZXMocmVzcG9uc2UuZGF0YSkNCiAgICAgICAgYXNzZXJ0
ICJMZWF0aGVyIFdvcmxkIiBpbiBuYW1lcw0KICAgICAgICBhc3NlcnQgIkxlYXRoZXIgQmFnIiBpbiBuYW1lcw0KDQogICAgZGVm
IHRlc3RfbWF0Y2hfaXNfY2FzZV9pbnNlbnNpdGl2ZShzZWxmKToNCiAgICAgICAgYml6ID0gbWFrZV9idXNpbmVzcygiTGVhdGhl
ciBXb3JsZCIpDQoNCiAgICAgICAgcmVzcG9uc2UgPSBzZWxmLmNsaWVudC5nZXQoU0VBUkNIX1VSTCwgeyJxIjogIkxFQVRIRVIg
d29yIn0pDQoNCiAgICAgICAgYXNzZXJ0IGJpei5idXNpbmVzc19uYW1lIGluIF9uYW1lcyhyZXNwb25zZS5kYXRhKQ0KDQogICAg
ZGVmIHRlc3Rfcm93c193aXRoX251bGxfc2VhcmNoX3ZlY3Rvcl9hcmVfc3RpbGxfZm91bmQoc2VsZik6DQogICAgICAgIGNhdCA9
IG1ha2VfY2F0ZWdvcnkoKQ0KICAgICAgICBiaXogPSBtYWtlX2J1c2luZXNzKCJMZWF0aGVyIFdvcmxkIikNCiAgICAgICAgcHJv
ZHVjdCA9IG1ha2VfcHJvZHVjdChiaXosIGNhdCwgIkxlYXRoZXIgQmFnIikNCiAgICAgICAgQnVzaW5lc3NQcm9maWxlLm9iamVj
dHMuZmlsdGVyKHBrPWJpei5waykudXBkYXRlKHNlYXJjaF92ZWN0b3I9Tm9uZSkNCiAgICAgICAgUHJvZHVjdC5vYmplY3RzLmZp
bHRlcihwaz1wcm9kdWN0LnBrKS51cGRhdGUoc2VhcmNoX3ZlY3Rvcj1Ob25lKQ0KDQogICAgICAgIHJlc3BvbnNlID0gc2VsZi5j
bGllbnQuZ2V0KFNFQVJDSF9VUkwsIHsicSI6ICJsZWF0aGVyIn0pDQoNCiAgICAgICAgbmFtZXMgPSBfbmFtZXMocmVzcG9uc2Uu
ZGF0YSkNCiAgICAgICAgYXNzZXJ0ICJMZWF0aGVyIFdvcmxkIiBpbiBuYW1lcw0KICAgICAgICBhc3NlcnQgIkxlYXRoZXIgQmFn
IiBpbiBuYW1lcw0KDQogICAgZGVmIHRlc3RfYXJhYmljX3BhcnRpYWxfd29yZChzZWxmKToNCiAgICAgICAgY2F0ID0gbWFrZV9j
YXRlZ29yeSgpDQogICAgICAgIGJpeiA9IG1ha2VfYnVzaW5lc3MoItmF2KrYrNixINin2YTYrNmE2YjYryIpDQogICAgICAgIG1h
a2VfcHJvZHVjdChiaXosIGNhdCwgItit2LDYp9ihINis2YTYryDYt9io2YrYudmKIikNCg0KICAgICAgICByZXNwb25zZSA9IHNl
bGYuY2xpZW50LmdldChTRUFSQ0hfVVJMLCB7InEiOiAi2K3YsCJ9KQ0KDQogICAgICAgIGFzc2VydCAi2K3YsNin2KEg2KzZhNiv
INi32KjZiti52YoiIGluIF9uYW1lcyhyZXNwb25zZS5kYXRhKQ0KDQogICAgZGVmIHRlc3RfdW5yZWxhdGVkX3F1ZXJ5X3N0aWxs
X3JldHVybnNfbm90aGluZyhzZWxmKToNCiAgICAgICAgY2F0ID0gbWFrZV9jYXRlZ29yeSgpDQogICAgICAgIGJpeiA9IG1ha2Vf
YnVzaW5lc3MoIkxlYXRoZXIgV29ybGQiKQ0KICAgICAgICBtYWtlX3Byb2R1Y3QoYml6LCBjYXQsICJMZWF0aGVyIEJhZyIpDQoN
CiAgICAgICAgcmVzcG9uc2UgPSBzZWxmLmNsaWVudC5nZXQoU0VBUkNIX1VSTCwgeyJxIjogInp6enpxcXEifSkNCg0KICAgICAg
ICBhc3NlcnQgcmVzcG9uc2UuZGF0YVsiaXRlbXMiXSA9PSBbXQ0KDQogICAgZGVmIHRlc3RfcGFydGlhbF9xdWVyeV9wYWdpbmF0
aW9uX2hhc19ub19kdXBsaWNhdGVzKHNlbGYpOg0KICAgICAgICBjYXQgPSBtYWtlX2NhdGVnb3J5KCkNCiAgICAgICAgYml6ID0g
bWFrZV9idXNpbmVzcygiTGVhdGhlciBXb3JsZCIpDQogICAgICAgIGZvciBpIGluIHJhbmdlKDcpOg0KICAgICAgICAgICAgbWFr
ZV9wcm9kdWN0KGJpeiwgY2F0LCBmIkxlYXRoZXIgSXRlbSB7aX0iKQ0KDQogICAgICAgIHNlZW4sIGN1cnNvciA9IFtdLCBOb25l
DQogICAgICAgIGZvciBfIGluIHJhbmdlKDEwKToNCiAgICAgICAgICAgIHBhcmFtcyA9IHsicSI6ICJsZWF0IiwgInBhZ2Vfc2l6
ZSI6IDN9DQogICAgICAgICAgICBpZiBjdXJzb3I6DQogICAgICAgICAgICAgICAgcGFyYW1zWyJjdXJzb3IiXSA9IGN1cnNvcg0K
ICAgICAgICAgICAgZGF0YSA9IHNlbGYuY2xpZW50LmdldChTRUFSQ0hfVVJMLCBwYXJhbXMpLmRhdGENCiAgICAgICAgICAgIHNl
ZW4uZXh0ZW5kKChpWyJyZXN1bHRfdHlwZSJdLCBpWyJpZCJdKSBmb3IgaSBpbiBkYXRhWyJpdGVtcyJdKQ0KICAgICAgICAgICAg
Y3Vyc29yID0gZGF0YVsibmV4dF9jdXJzb3IiXQ0KICAgICAgICAgICAgaWYgbm90IGN1cnNvcjoNCiAgICAgICAgICAgICAgICBi
cmVhaw0KDQogICAgICAgIGFzc2VydCBsZW4oc2VlbikgPT0gbGVuKHNldChzZWVuKSkgPT0gOA0K
'@
    }
    @{
        Repo = 'app'
        Path = 'search/management/__init__.py'
        ExpectedHash = $null
        B64 = @'

'@
    }
    @{
        Repo = 'app'
        Path = 'search/management/commands/__init__.py'
        ExpectedHash = $null
        B64 = @'

'@
    }
    @{
        Repo = 'app'
        Path = 'search/management/commands/rebuild_search_vectors.py'
        ExpectedHash = $null
        B64 = @'
IiIiDQpSZWJ1aWxkcyBQcm9kdWN0LnNlYXJjaF92ZWN0b3IgLyBCdXNpbmVzc1Byb2ZpbGUuc2VhcmNoX3ZlY3RvciBmb3IgZXZl
cnkNCnJvdyAoc29mdC1kZWxldGVkIG9uZXMgaW5jbHVkZWQpLg0KDQpUaGUgcG9zdF9zYXZlIHNpZ25hbCBvbmx5IGtlZXBzIHZl
Y3RvcnMgZnJlc2ggZm9yIHJvd3Mgc2F2ZWQgdGhyb3VnaCB0aGUNCk9STSdzIC5zYXZlKCk7IHJvd3MgY3JlYXRlZCBiZWZvcmUg
dGhlIHNpZ25hbCBleGlzdGVkLCBidWxrLWNyZWF0ZWQgb3INCmNoYW5nZWQgd2l0aCBRdWVyeVNldC51cGRhdGUoKSBrZWVwIGEg
TlVMTC9zdGFsZSB2ZWN0b3IuIFNlYXJjaCBubyBsb25nZXINCmRlcGVuZHMgb24gdGhlIHZlY3RvciBhbG9uZSAoc2VlIHNlYXJj
aC9zZXJ2aWNlcy5weSksIGJ1dCBhIGNvcnJlY3QNCnZlY3RvciBzdGlsbCBnaXZlcyBiZXR0ZXIgcmFua2luZywgc28gcnVuIHRo
aXMgb25jZSBhZnRlciBkZXBsb3lpbmc6DQoNCiAgICBweXRob24gbWFuYWdlLnB5IHJlYnVpbGRfc2VhcmNoX3ZlY3RvcnMNCiIi
Ig0KDQpmcm9tIGRqYW5nby5jb250cmliLnBvc3RncmVzLnNlYXJjaCBpbXBvcnQgU2VhcmNoVmVjdG9yDQpmcm9tIGRqYW5nby5j
b3JlLm1hbmFnZW1lbnQuYmFzZSBpbXBvcnQgQmFzZUNvbW1hbmQNCg0KZnJvbSBidXNpbmVzc2VzLm1vZGVscyBpbXBvcnQgQnVz
aW5lc3NQcm9maWxlDQpmcm9tIHByb2R1Y3RzLm1vZGVscyBpbXBvcnQgUHJvZHVjdA0KDQoNCmNsYXNzIENvbW1hbmQoQmFzZUNv
bW1hbmQpOg0KICAgIGhlbHAgPSAiUmVidWlsZCBzZWFyY2hfdmVjdG9yIGZvciBhbGwgcHJvZHVjdHMgYW5kIGJ1c2luZXNzIHBy
b2ZpbGVzLiINCg0KICAgIGRlZiBoYW5kbGUoc2VsZiwgKmFyZ3MsICoqb3B0aW9ucyk6DQogICAgICAgIHByb2R1Y3RzID0gUHJv
ZHVjdC5hbGxfb2JqZWN0cy5hbGwoKS51cGRhdGUoDQogICAgICAgICAgICBzZWFyY2hfdmVjdG9yPVNlYXJjaFZlY3RvcigibmFt
ZSIsICJkZXNjcmlwdGlvbiIpDQogICAgICAgICkNCiAgICAgICAgYnVzaW5lc3NlcyA9IEJ1c2luZXNzUHJvZmlsZS5hbGxfb2Jq
ZWN0cy5hbGwoKS51cGRhdGUoDQogICAgICAgICAgICBzZWFyY2hfdmVjdG9yPVNlYXJjaFZlY3RvcigiYnVzaW5lc3NfbmFtZSIs
ICJkZXNjcmlwdGlvbiIpDQogICAgICAgICkNCiAgICAgICAgc2VsZi5zdGRvdXQud3JpdGUoDQogICAgICAgICAgICBzZWxmLnN0
eWxlLlNVQ0NFU1MoDQogICAgICAgICAgICAgICAgZiJSZWJ1aWx0IHNlYXJjaF92ZWN0b3I6IHtwcm9kdWN0c30gcHJvZHVjdHMs
IHtidXNpbmVzc2VzfSBidXNpbmVzc2VzLiINCiAgICAgICAgICAgICkNCiAgICAgICAgKQ0K
'@
    }
)

# ---- Mobile: patch search_provider.dart in place (keeps your local changes) ----
function Count-Occurrences([string]$text, [string]$needle) {
    return ($text.Split(@($needle), [System.StringSplitOptions]::None).Count - 1)
}
$Patches = @(
    @{ Old = @'
  String? _currentQuery;
  SearchFilters _currentFilters = const SearchFilters();
'@
       New = @'
  String? _currentQuery;
  SearchFilters _currentFilters = const SearchFilters();

  /// Monotonic id of the most recent [search] call. A slow response for
  /// an OLDER query (e.g. the text typed a moment ago) must never
  /// overwrite the results of the query currently on screen, and a
  /// [loadMore] page fetched for an older query must never be appended
  /// to a newer result list.
  int _searchRequestId = 0;
'@ },
    @{ Old = @'
    _currentFilters = filters;

    state = const AsyncValue<SearchState>.loading();
    state = await AsyncValue.guard<SearchState>(() async {
'@
       New = @'
    _currentFilters = filters;
    final requestId = ++_searchRequestId;

    state = const AsyncValue<SearchState>.loading();
    final result = await AsyncValue.guard<SearchState>(() async {
'@ },
    @{ Old = @'
        hasSearched: true,
      );
    });
  }
'@
       New = @'
        hasSearched: true,
      );
    });

    // A newer search() started while this one was in flight - drop this
    // (now stale) result instead of overwriting the newer one.
    if (requestId != _searchRequestId) return;
    state = result;
  }
'@ },
    @{ Old = @'
    state = AsyncData(current.copyWith(isLoadingMore: true));
'@
       New = @'
    final requestId = _searchRequestId;
    state = AsyncData(current.copyWith(isLoadingMore: true));
'@ },
    @{ Old = @'
            cursor: current.nextCursor,
          );
      state = AsyncData(
'@
       New = @'
            cursor: current.nextCursor,
          );
      // The user started a new search while this page was loading.
      if (requestId != _searchRequestId) return;
      state = AsyncData(
'@ },
    @{ Old = @'
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
'@
       New = @'
    } catch (_) {
      if (requestId == _searchRequestId) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
      rethrow;
'@ }
)
$mobileTarget = Join-Path $MobilePath 'lib\features\search\presentation\search_provider.dart'
if (-not (Test-Path -LiteralPath $mobileTarget)) { throw "File not found: $mobileTarget" }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$mobileRaw = [System.IO.File]::ReadAllText($mobileTarget)
$mobileUsesCrlf = $mobileRaw.Contains("`r`n")
$mobileText = $mobileRaw -replace "`r`n", "`n"
$mobileAlreadyPatched = $mobileText.Contains('_searchRequestId')
if (-not $mobileAlreadyPatched) {
    $i = 0
    foreach ($p in $Patches) {
        $i++
        $old = ($p.Old -replace "`r`n", "`n")
        $new = ($p.New -replace "`r`n", "`n")
        $n = Count-Occurrences $mobileText $old
        if ($n -ne 1) {
            throw "search_provider.dart: patch $i matched $n times (expected 1). Nothing was changed. Send me this file."
        }
        $mobileText = $mobileText.Replace($old, $new)
    }
}

# ---- Pass 1: validate everything before touching anything ----
$plan = @()
foreach ($f in $Files) {
    $root = if ($f.Repo -eq 'app') { $BackendPath } else { $MobilePath }
    $target = Join-Path $root ($f.Path -replace '/', '\')
    $exists = Test-Path -LiteralPath $target
    $b64 = (($f.B64 -split "`r?`n") -join '')
    if ($b64) { $newBytes = [Convert]::FromBase64String($b64) } else { $newBytes = New-Object byte[] 0 }
    $skip = $false
    if ($exists) {
        $currentBytes = [System.IO.File]::ReadAllBytes($target)
        $current = Get-NormalizedHash $currentBytes
        if ($current -eq (Get-NormalizedHash $newBytes)) {
            $skip = $true   # already applied
        } elseif ($f.ExpectedHash -and -not $Force -and $current -ne $f.ExpectedHash) {
            throw "File differs from GitHub main, refusing to overwrite: $target`n" +
                  "Push/commit or stash your local changes, or re-run with -Force."
        }
    }
    if ($f.ExpectedHash -and -not $exists) { throw "Expected existing file not found: $target" }
    $plan += [pscustomobject]@{ Target = $target; Exists = $exists; Skip = $skip; Bytes = $newBytes }
}

# ---- Pass 2: write ----
foreach ($item in $plan) {
    if ($item.Skip) {
        Write-Host ("  skip   " + $item.Target + " (already applied)") -ForegroundColor Yellow
        continue
    }
    $dir = Split-Path -Parent $item.Target
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ($item.Exists) {
        Copy-Item -LiteralPath $item.Target -Destination ($item.Target + '.bak_search_fix') -Force
    }
    [System.IO.File]::WriteAllBytes($item.Target, [byte[]]$item.Bytes)   # UTF-8, no BOM, CRLF kept
    Write-Host ("  wrote  " + $item.Target) -ForegroundColor Green
}

if ($mobileAlreadyPatched) {
    Write-Host ("  skip   " + $mobileTarget + " (already patched)") -ForegroundColor Yellow
} else {
    Copy-Item -LiteralPath $mobileTarget -Destination ($mobileTarget + '.bak_search_fix') -Force
    if ($mobileUsesCrlf) { $mobileText = $mobileText -replace "`n", "`r`n" }
    [System.IO.File]::WriteAllText($mobileTarget, $mobileText, $utf8NoBom)
    Write-Host ("  patched " + $mobileTarget) -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1) Backend - restart the server, then (once) rebuild old search vectors:"
Write-Host "       docker compose exec web python manage.py rebuild_search_vectors"
Write-Host "       (or: python manage.py rebuild_search_vectors)"
Write-Host "  2) Backend - run the tests:   pytest search -q"
Write-Host "  3) Mobile  - no new packages. Stop and re-run the app (hot restart):  flutter run"
Write-Host "  Backups: *.bak_search_fix (delete them once you are happy)."