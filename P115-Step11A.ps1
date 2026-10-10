# P-115 STEP 11A - create UI_QA_CHECKLIST.md (structure + Customer section)
param([switch]$Force)
$ErrorActionPreference = 'Stop'
Set-Location 'D:\Cavallo\social_commerce_app'
if ((Test-Path 'UI_QA_CHECKLIST.md') -and -not $Force) { throw 'UI_QA_CHECKLIST.md already exists. Use -Force to overwrite.' }
$content = @'
# UI QA Checklist

## Header
- Date: ________
- Branch: ________
- Device name: ________
- App version / build: ________

## طريقة التسجيل
- كل خانة نتيجة تبدأ فاضية: ☐
- بعد الفحص على الجهاز حوّلها بإيدك إلى ✅ (سليم) أو ❌ (فيه عيب) مع ملاحظة في عمود الملاحظات.
- ❌ لازم يتسجل في "Defects Log" بالأسفل.
- لا يُكتب أي نتيجة مسبقاً. الملف ده اتكتب بدون تشغيل على جهاز.
- التركيبات الأربعة: Light-EN، Light-AR، Dark-EN، Dark-AR.

## Customer

مصدر القائمة: navigation_manifest.dart + shell_branches.dart + app_router.dart + ملفات *_screen.dart في qa_recon.txt.
الـbottom bar للـCustomer: Home، Explore، Saved، Chats، Profile.
طريقة الوصول = تنقل ظاهر فقط، بدون deep-link يدوي.

| الشاشة | Route | طريقة الوصول | Light-EN | Light-AR | Dark-EN | Dark-AR | ملاحظات |
|--------|-------|--------------|----------|----------|---------|---------|---------|
| home_feed_screen | /home | Bottom bar، تاب 1 | ☐ | ☐ | ☐ | ☐ | |
| discover_screen | /discover | Bottom bar، تاب 2 | ☐ | ☐ | ☐ | ☐ | |
| saved_screen | /saved | Bottom bar، تاب 3؛ صف في Profile hub | ☐ | ☐ | ☐ | ☐ | |
| chat_list_screen | /chat | Bottom bar، تاب 4؛ أيقونة chats في top bar الـHome | ☐ | ☐ | ☐ | ☐ | |
| profile_hub_screen | /profile | Bottom bar، تاب 5 | ☐ | ☐ | ☐ | ☐ | |
| search_screen | /search | شريط البحث في Explore؛ أيقونة البحث في الـempty states | ☐ | ☐ | ☐ | ☐ | |
| notification_center_screen | /notifications | أيقونة الجرس في top bar الـHome | ☐ | ☐ | ☐ | ☐ | |
| notification_preferences_screen | /notifications/preferences | صف في Profile hub؛ header الـNotification center | ☐ | ☐ | ☐ | ☐ | |
| business_profile_public_screen | /business/:id | Avatar أو اسم في feed وsearch وstory header وchat header وsaved وnotifications | ☐ | ☐ | ☐ | ☐ | |
| product_detail_screen | /product/:id | كروت في feed وprofile tabs وsearch وsaved وnotifications وكروت الشات المشاركة | ☐ | ☐ | ☐ | ☐ | |
| post_detail_screen | /post/:id | نفس الكروت (in-context) | ☐ | ☐ | ☐ | ☐ | |
| reel_detail_screen | /reel/:id | نفس الكروت (in-context) | ☐ | ☐ | ☐ | ☐ | |
| story_viewer_screen | /stories/:id | Story rings في Home tray وشريط القصص في Explore | ☐ | ☐ | ☐ | ☐ | |
| chat_thread_screen | /chat/:id | صف في قائمة الشات؛ زر Message في بروفايل Business؛ إشعار شات | ☐ | ☐ | ☐ | ☐ | يحتاج Conversation؛ لا يُفتح بكتابة المسار |

إجراءات من صف الـProfile hub (مش شاشات): Appearance ☐ | Language ☐ | Logout ☐

الـCustomer ما يشوفش أي مدخل لـ: Business console، create sheet، شاشات الـforms، Edit business profile، Moderation ☐

### بنود الفحص لكل شاشة أعلاه (تتكرر في كل تركيبة)
- ☐ RTL mirroring في AR (الاتجاه، back، chevron، padding)
- ☐ النص والأيقونات مقروءة في Dark
- ☐ لا نص مقصوص أو overflow
- ☐ Empty / Loading / Error states ظاهرة وسليمة
- ☐ لا نصوص إنجليزية في النسخة العربية

### بنود إضافية حسب المجموعة
**Shell tabs (home، discover، saved، chat_list، profile_hub)**
- ☐ الـbottom bar فيه 5 تابات بالترتيب: Home، Explore، Saved، Chats، Profile
- ☐ التاب المختار واضح، والـbadge مقروء
- ☐ التبديل بين التابات يحافظ على حالة كل تاب

**home_feed_screen**
- ☐ Story tray ظاهر ويفتح story_viewer_screen
- ☐ أيقونتا chats والجرس في الـtop bar تفتحا الشاشتين الصح

**discover_screen / search_screen**
- ☐ شريط البحث يفتح search_screen
- ☐ نتيجة بدون نتائج وحالة الخطأ سليمتين

**saved_screen**
- ☐ الـempty state واضح، وإلغاء الحفظ ينعكس

**chat_list_screen**
- ☐ الصف: الاسم، آخر رسالة، الوقت، عدّاد غير المقروء مقروءين وغير مقصوصين

**profile_hub_screen**
- ☐ صفوف Saved وNotification preferences وAppearance وLanguage وLogout ظاهرة
- ☐ تبديل الثيم واللغة يطبق فوراً بدون إعادة تشغيل

**notification_center_screen / notification_preferences_screen**
- ☐ تجميع الإشعارات بالتاريخ مقروء، والضغط على إشعار يفتح الوجهة الصح
- ☐ مفاتيح التفضيلات ظاهرة وقيمتها محفوظة

**business_profile_public_screen**
- ☐ زر Message يفتح chat_thread_screen
- ☐ لا يظهر زر Edit للـCustomer

**product_detail_screen / post_detail_screen / reel_detail_screen**
- ☐ الوسائط والسعر والوصف مقروءة، وأزرار الحفظ والمشاركة تعمل

**story_viewer_screen**
- ☐ شريط التقدم والإغلاق واتجاه التنقل بين القصص صحيحين في AR

**chat_thread_screen (شكل فقط، الوظائف في 11C)**
- ☐ الفقاعات (مرسلة/مستلمة) مقروءة في Dark وتنعكس في AR
- ☐ شريط الإدخال وأيقونة send يتعكسوا في AR

### تحتاج تأكيد
- كل ملفات *_screen.dart ليها مدخل في الـmanifest لنوع حساب واحد على الأقل، فمفيش شاشة ناقصة.
- الشاشات اللي مدخلها in-context فقط للـCustomer (business_profile_public، product_detail، post_detail، reel_detail، story_viewer، chat_thread): أكّد على الجهاز إن المدخل ظاهر فعلاً. ☐

## Business
<!-- STEP 11B placeholder -->

## Staff
<!-- STEP 11B placeholder -->

## Cross-cutting
<!-- STEP 11C placeholder -->

## Defects Log

| # | الشاشة | التركيبة | الوصف | الحالة |
|---|--------|----------|-------|--------|
| | | | | |
'@
Set-Content -Path 'UI_QA_CHECKLIST.md' -Value $content -Encoding utf8
Write-Host 'Created UI_QA_CHECKLIST.md'