# P-115 STEP 11B - fill the Business and Staff sections of UI_QA_CHECKLIST.md
$ErrorActionPreference = 'Stop'
Set-Location 'D:\Cavallo\social_commerce_app'
$Path = 'UI_QA_CHECKLIST.md'
if (-not (Test-Path $Path)) { throw 'UI_QA_CHECKLIST.md not found. Run P115-Step11A.ps1 first.' }

$business = @'
مصدر القائمة: navigation_manifest.dart + shell_branches.dart + app_router.dart + business_console_shell.dart.
الـbottom bar للـBusiness: Home، Explore، Create (+)، Chats، Profile. الـSaved مش تاب، بيتفتح من صف في Profile hub.
الـBusiness console له bottom bar خاص: Products، Content، Stories، Analytics. مسار /business-console نفسه بيحوّل لـ Products.
الشاشات المشتركة مع Customer (home، discover، search، chats، notifications، الخ) موجودة في جدول Customer. المطلوب هنا تتفحص بحساب Business كمان (صف تحت).

| الشاشة | Route | طريقة الوصول | Light-EN | Light-AR | Dark-EN | Dark-AR | ملاحظات |
|--------|-------|--------------|----------|----------|---------|---------|---------|
| business_profile_edit_screen | /business-profile/edit | صف في Profile hub (مجموعة Business tools)؛ زر Edit في البروفايل العام للـBusiness | ☐ | ☐ | ☐ | ☐ | |
| product_list_screen | /business-console/products | Profile hub (Business tools)؛ اختصارات header تاب 5؛ تاب Products في console bar | ☐ | ☐ | ☐ | ☐ | يحتوي dashboard cards في الـheader |
| content_list_screen | /business-console/content | Profile hub (Business tools)؛ اختصارات header تاب 5؛ تاب Content | ☐ | ☐ | ☐ | ☐ | |
| story_list_screen | /business-console/stories | Profile hub (Business tools)؛ اختصارات header تاب 5؛ تاب Stories | ☐ | ☐ | ☐ | ☐ | |
| analytics_screen | /business-console/analytics | Profile hub (Business tools)؛ اختصارات header تاب 5؛ تاب Analytics | ☐ | ☐ | ☐ | ☐ | |
| product_form_screen | /business-console/products/form | Create sheet (Product)؛ زر Add في قائمة المنتجات؛ تعديل منتج من القائمة | ☐ | ☐ | ☐ | ☐ | جرّب إنشاء وتعديل |
| post_form_screen | /business-console/content/post | Create sheet (Post)؛ زر Add في قائمة المحتوى | ☐ | ☐ | ☐ | ☐ | |
| reel_form_screen | /business-console/content/reel | Create sheet (Reel)؛ زر Add في قائمة المحتوى | ☐ | ☐ | ☐ | ☐ | |
| story_creation_screen | /business-console/stories/create | Create sheet (Story)؛ زر Add في قائمة القصص | ☐ | ☐ | ☐ | ☐ | |
| saved_screen | /saved | صف في Profile hub (مش تاب للـBusiness) | ☐ | ☐ | ☐ | ☐ | |
| الشاشات المشتركة الـ13 الباقية (جدول Customer) بحساب Business | حسب الجدول | نفس مداخل Customer، والـbottom bar مختلف | ☐ | ☐ | ☐ | ☐ | سجّل أي عيب في Defects Log |

الـCreate sheet (مش شاشة): تاب 3 (+) في الـbottom bar يفتح sheet فيه Product وPost وReel وStory ☐
إجراءات صف الـProfile hub (مش شاشات): Appearance ☐ | Language ☐ | Logout ☐
Business ما يشوفش أي مدخل لـ Moderation ☐

### بنود الفحص لكل شاشة أعلاه (تتكرر في كل تركيبة)
- ☐ RTL mirroring في AR (الاتجاه، back، chevron، padding)
- ☐ النص والأيقونات مقروءة في Dark
- ☐ لا نص مقصوص أو overflow
- ☐ Empty / Loading / Error states ظاهرة وسليمة
- ☐ لا نصوص إنجليزية في النسخة العربية

### بنود إضافية حسب المجموعة
**Business console (products، content، stories، analytics)**
- ☐ الـconsole bar فيه 4 تابات بالترتيب: Products، Content، Stories، Analytics
- ☐ الضغط على التاب الحالي يرجّع لجذره
- ☐ مدخل الـconsole يفتح على Products
- ☐ بانر رفع القصص (لو فيه رفع شغال) ظاهر ومقروء فوق المحتوى

**product_list_screen**
- ☐ كروت الـdashboard في الـheader مقروءة وغير مقصوصة
- ☐ زر Add وتعديل منتج من القائمة يفتحا product_form_screen

**content_list_screen / story_list_screen**
- ☐ Add (Post / Reel / Story) يفتح الفورم الصح
- ☐ الحالة (status chip) مقروءة في Dark

**analytics_screen**
- ☐ تبديل المدى 7 / 14 يوم يشتغل
- ☐ الرسوم مقروءة في Dark، والـempty مش بيعرض أصفار
- ☐ الخطأ فيه Retry

**الـforms (product، post، reel، story_creation)**
- ☐ رسائل الـvalidation مترجمة وظاهرة
- ☐ الكيبورد ما يغطيش الحقول أو الأزرار
- ☐ Save / Cancel واضحين، والرجوع بدون حفظ ما يحفظش

**business_profile_edit_screen**
- ☐ الحقول تتعبى بالبيانات الحالية، والحفظ ينعكس في البروفايل العام

### شاشات خاصة
**business_onboarding_screen** (مش في جدول الوصول: بيتفرض بالـredirect لحساب Business ملوش BusinessProfile)
- ☐ بعد تسجيل Business جديد يظهر قبل أي شاشة تانية
- ☐ التنقل لأي شاشة تانية يرجّع له لحد ما البروفايل يتعمل
- ☐ بعد الإنشاء يوصّل للتطبيق
- ☐ RTL وDark ونصوص عربية سليمة

### تحتاج تأكيد
- كل ملفات *_screen.dart الخاصة بالـBusiness ليها مدخل في الـmanifest، فمفيش شاشة ناقصة.
- مدخل "اختصارات header تاب 5" لشاشات الـconsole: أكّد على الجهاز إنه ظاهر فعلاً. ☐
- تعديل منتج من القائمة (onEditProduct في الـrouter) مش مكتوب كمدخل منفصل في الـmanifest: أكّد إنه ظاهر. ☐
'@

$staff = @'
مصدر القائمة: navigation_manifest.dart + shell_branches.dart + app_router.dart.
الـbottom bar للـStaff: Home، Explore، Moderation (فيه badge للـpending)، Chats، Profile. الـSaved بيتفتح من صف في Profile hub.
حساب Staff = moderator أو staff (navAudienceForUser). الشاشات المشتركة مع Customer في جدول Customer، ولازم تتفحص بحساب Staff كمان (صف تحت).

| الشاشة | Route | طريقة الوصول | Light-EN | Light-AR | Dark-EN | Dark-AR | ملاحظات |
|--------|-------|--------------|----------|----------|---------|---------|---------|
| moderation_queue_screen | /moderation | Bottom bar، تاب 3 (badge)؛ صف في Profile hub (مجموعة Moderation) | ☐ | ☐ | ☐ | ☐ | |
| moderation_review_screen | /moderation/review | صف عنصر في الـqueue | ☐ | ☐ | ☐ | ☐ | يحتاج QueueItem؛ بدونه يرجع للـqueue |
| saved_screen | /saved | صف في Profile hub (مش تاب للـStaff) | ☐ | ☐ | ☐ | ☐ | |
| الشاشات المشتركة الـ13 الباقية (جدول Customer) بحساب Staff | حسب الجدول | نفس مداخل Customer، والـbottom bar مختلف | ☐ | ☐ | ☐ | ☐ | سجّل أي عيب في Defects Log |

إجراءات صف الـProfile hub (مش شاشات): Appearance ☐ | Language ☐ | Logout ☐
Staff ما يشوفش أي مدخل لـ Business console أو Create أو شاشات الـforms أو Edit business profile ☐

### بنود الفحص لكل شاشة أعلاه (تتكرر في كل تركيبة)
- ☐ RTL mirroring في AR (الاتجاه، back، chevron، padding)
- ☐ النص والأيقونات مقروءة في Dark
- ☐ لا نص مقصوص أو overflow
- ☐ Empty / Loading / Error states ظاهرة وسليمة
- ☐ لا نصوص إنجليزية في النسخة العربية

### بنود إضافية حسب المجموعة
**moderation_queue_screen**
- ☐ صف العنصر: الصورة المصغرة، الـpriority badge، الـage chip مقروءة وغير مقصوصة
- ☐ الـbadge على التاب مقروء وبيتحدث
- ☐ الـchevron بيتعكس في AR
- ☐ الـqueue الفاضي له empty state واضح

**moderation_review_screen**
- ☐ تفاصيل العنصر والمحتوى المراجَع ظاهرين ومقروءين
- ☐ أزرار القرار واضحة وبتطلع نتيجة سليمة
- ☐ الرجوع للـqueue يحدّث القائمة

### تحتاج تأكيد
- كل ملفات *_screen.dart الخاصة بالـStaff ليها مدخل في الـmanifest، فمفيش شاشة ناقصة.
- إن كل أزرار القرار في المراجعة بتطلب confirmation قبل التنفيذ: يتفحص في 11C. ☐
'@

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.Encoding]::UTF8)
$eol = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
$lines = New-Object System.Collections.Generic.List[string]
$lines.AddRange([string[]]($raw -split "`r?`n"))

function Set-SectionBody([System.Collections.Generic.List[string]]$L, [string]$Title, [string]$Body) {
    $hits = @(); for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i] -match "^##\s+$Title\s*$") { $hits += $i } }
    if ($hits.Count -ne 1) { throw "Expected exactly 1 '## $Title' heading, found $($hits.Count)." }
    $s = $hits[0]; $e = $L.Count
    for ($j = $s + 1; $j -lt $L.Count; $j++) { if ($L[$j] -match '^##\s') { $e = $j; break } }
    $old = if ($e -gt $s + 1) { ($L.GetRange($s + 1, $e - $s - 1) -join "`n") } else { '' }
    if ($old -notmatch '(?i)placeholder|11B') { throw "Section '$Title' is not an empty placeholder. Not touching it." }
    $L.RemoveRange($s + 1, $e - $s - 1)
    $new = @('') + ($Body -split "`r?`n") + @('')
    $L.InsertRange($s + 1, [string[]]$new)
}

Set-SectionBody $lines 'Business' $business
Set-SectionBody $lines 'Staff' $staff

Copy-Item $Path "$Path.bak" -Force
[System.IO.File]::WriteAllText((Resolve-Path $Path), ($lines -join $eol), (New-Object System.Text.UTF8Encoding($true)))
Write-Host 'Updated UI_QA_CHECKLIST.md (Business + Staff). Backup: UI_QA_CHECKLIST.md.bak'