# P-115 STEP 11C - fill the Cross-cutting section and add Sign-off in UI_QA_CHECKLIST.md
$ErrorActionPreference = 'Stop'
Set-Location 'D:\Cavallo\social_commerce_app'
$Path = 'UI_QA_CHECKLIST.md'
if (-not (Test-Path $Path)) { throw 'UI_QA_CHECKLIST.md not found.' }

$body = @'
مصدر القائمة: بنود الـCross-cutting من خطة P-115 STEP 11. الجداول فوق (Customer / Business / Staff) هي مصدر الشاشات.
النتائج تبدأ فاضية: ☐

### 1) Reachability (لكل نوع حساب)
مرجع الشاشات والمداخل: جدول كل حساب أعلاه.
- ☐ Customer: كل صفوف جدول Customer اتوصّل لها بتنقل ظاهر بدون deep-link يدوي
- ☐ Business: كل صفوف جدول Business (بما فيها الـconsole والـforms) اتوصّل لها بتنقل ظاهر بدون deep-link يدوي
- ☐ Staff: كل صفوف جدول Staff اتوصّل لها بتنقل ظاهر بدون deep-link يدوي
- ☐ الـbottom bar لكل نوع حساب بالترتيب المكتوب في جدوله
- ☐ كل شاشة تتفتح من مدخلها المكتوب ترجع بزر الرجوع للمكان الصح

### 2) Localization
- ☐ لا نصوص إنجليزية hardcoded ظاهرة في النسخة العربية (شاشات، dialogs، snackbars، tooltips، رسائل خطأ، empty states)
- ☐ الجمع العربي صحيح (zero / one / two / few / many / other) في كل عدّاد: متابعين، منتجات، غير مقروء، إشعارات، قصص، رسائل
- ☐ الأرقام بتنسيق اللغة المختارة (EN / AR)
- ☐ التواريخ والأوقات بتنسيق اللغة المختارة، بما فيها فواصل التاريخ في الشات
- ☐ أيقونة send في الشات بتتعكس في RTL
- ☐ تبديل اللغة يتطبق بدون إعادة تشغيل

### 3) Theme correctness
- ☐ تبديل Light/Dark أثناء الاستخدام يتطبق فوراً بدون إعادة تشغيل
- ☐ التبديل وإنت جوه شاشة مفتوحة (شات، فورم، تفاصيل) ما يكسرش الحالة
- ☐ التباين مقروء في Light وDark: نص ثانوي، chips، badges، placeholders، العناصر المعطّلة
- ☐ الـbottom bar والـdialogs والـbottom sheets بتتبع الثيم الحالي

### 4) Chat functionality (جهاز حقيقي، حسابين على جهازين)
- ☐ إرسال: الرسالة تظهر فوراً ثم تتأكد
- ☐ استقبال والـthread مفتوح
- ☐ استقبال والـthread مقفول: قائمة الشات تتحدّث
- ☐ Offline queue: قفل النت، ابعت رسالة، تظهر كـ queued
- ☐ رجوع النت: الرسالة المتأخرة تتبعت تلقائياً بنفس الترتيب وبدون تكرار
- ☐ Read ticks: sent / delivered / read صح
- ☐ Typing indicator يظهر عند الطرف التاني ويختفي
- ☐ Block: confirmation قبل التنفيذ، ثم السلوك صحيح بعده
- ☐ Report: اختيار السبب ثم تأكيد
- ☐ كل البنود أعلاه مكررة في AR (RTL)

### 5) Moderation visibility
- ☐ سبب الرفض (rejection reason) ظاهر للـBusiness دائماً على أي عنصر مرفوض، في القائمة وفي التفاصيل
- ☐ كل إجراء مدمّر بيطلب confirmation قبل التنفيذ. سجّل كل إجراء لقيته (مثلاً حذف محتوى، block، رفض أو إزالة في المراجعة، logout): ________
- ☐ Cancel في الـconfirmation ما يغيّرش حاجة

## Sign-off
نتائج guard tests (تتسجل كما هي بعد التشغيل، ما تتملاش مسبقاً):
- Reachability: ________
- ARB parity: ________
- No-hardcoded-strings: ________

حالة المراجعة العربية (app_ar.arb): ☐ Pending   ☐ Completed

التوقيع: ________
التاريخ: ________
'@

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.Encoding]::UTF8)
$eol = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
$lines = New-Object System.Collections.Generic.List[string]
$lines.AddRange([string[]]($raw -split "`r?`n"))

if ($lines | Where-Object { $_ -match '^#{1,6}\s+.*Sign-?off' }) { throw 'A Sign-off heading already exists. Stopping to avoid duplicates.' }
$hits = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^##\s+Cross-cutting\s*$') { $hits += $i } }
if ($hits.Count -ne 1) { throw "Expected exactly 1 '## Cross-cutting' heading, found $($hits.Count)." }
$s = $hits[0]; $e = $lines.Count
for ($j = $s + 1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s') { $e = $j; break } }
$old = if ($e -gt $s + 1) { ($lines.GetRange($s + 1, $e - $s - 1) -join "`n") } else { '' }
if ($old -notmatch '(?i)placeholder|11C') { throw 'Cross-cutting is not an empty placeholder. Not touching it.' }

Copy-Item $Path "$Path.bak" -Force
$lines.RemoveRange($s + 1, $e - $s - 1)
$new = @('') + ($body -split "`r?`n") + @('')
$lines.InsertRange($s + 1, [string[]]$new)
[System.IO.File]::WriteAllText((Resolve-Path $Path), ($lines -join $eol), (New-Object System.Text.UTF8Encoding($true)))
Write-Host 'Updated UI_QA_CHECKLIST.md (Cross-cutting + Sign-off). Backup: UI_QA_CHECKLIST.md.bak'