# 🏏 SB CricScore - மொபைல் ஆப் அணி உருவாக்கம் & மொபைல் எண் சர்ச் திட்டம் (Implementation Plan)

> **File Location:** `IMPLEMENTATION_PLAN.md`  
> **Last Updated:** 2026-09-29  
> **Status:** Implementation in Progress  

---

## 📌 தேவைகளின் சுருக்கம் (Requirements Summary)

1. **📱 Profile-ல் "My Teams" & "+ Create Team":**
   - பயனர் தனது **Profile Screen**-லேயே சொந்தமாக எத்தனை அணிகள் வேண்டுமானாலும் உருவாக்கலாம்.
   - தான் உருவாக்கிய அனைத்து அணிகளையும் நிர்வகிக்கலாம் (Manage Squad, Matches).

2. **🔍 Team Name Availability Checker (டீம் பெயர் இருப்பு சோதனை):**
   - பயனர் பெயர் தட்டச்சு செய்யும் போது டேட்டாபேஸில் ஏற்கனவே உள்ளதா என நொடிப்பொழுதில் சரிபார்க்கும் API.
   - ஏற்கனவே இருந்தால் ❌ *"This team name is already taken! Please choose another name."*
   - புதிய பெயராக இருந்தால் ✅ *"Team name is available!"* என பச்சை நிற பேட்ஜ் காட்டும்.

3. **📞 Mobile Number + Name மூலம் வீரர்களைத் தேடும் வசதி (Unique Player Discovery):**
   - ஒரே பெயரில் பல வீரர்கள் இருக்கக்கூடும் என்பதால், **10-இலக்க மொபைல் எண் (Unique Phone Number)** மூலமாகவோ அல்லது **பெயர்** மூலமாகவோ தேடி அணியில் சேர்க்கும் வசதி.
   - சர்ச் முடிவுகளில் பிளேயரின் பெயர், மொபைல் எண், ரோல், பேட்டிங்/பௌலிங் ஸ்டைல் தோன்றும் ➔ 1-கிளிக் மூலம் அணியில் இணைக்கலாம்.

---

## 🗄️ 1. Database & Schema Updates
- `teams` அட்டவணை:
  - `owner_id` (INT - அணி உருவாக்கிய User ID)
  - `city` (VARCHAR(100) - ஊர் பெயர்)

---

## ⚙️ 2. Backend APIs (`api/team_ops.php` & `api/search_ops.php`)

### A. Team Name Availability Check API:
- `GET /api/team_ops.php?action=check_name&name=FCC`
- Response:
  ```json
  {
    "success": true,
    "available": false,
    "message": "Team name 'FCC' is already taken!"
  }
  ```

### B. User Team Creation API:
- `POST /api/team_ops.php?action=create_user_team`
- Payload: `{ "name": "Kovai Kings", "short_name": "KK", "city": "Coimbatore", "icon": "shield", "owner_id": 1 }`

### C. My Teams List API:
- `GET /api/team_ops.php?action=my_teams&user_id=1`
- Response: பயனர் உருவாக்கிய அணிகள் மற்றும் பிளேயர் எண்ணிக்கை.

### D. Dual Player Search (Phone + Name):
- `GET /api/search_ops.php?type=players&q=9876543210`
- Response: பெயர் அல்லது மொபைல் எண்ணிற்குப் பொருந்தும் வீரர்கள் பட்டியல்.

---

## 📱 3. Mobile App (Flutter UI) Screens

1. **`team_create_screen.dart`:**
   - Real-time Team Name Availability Checker with debounce.
   - Short Name, City, Icon selector.
   - Success callback to refresh profile.

2. **`player_profile_screen.dart`:**
   - "🛡️ My Teams" Section with horizontal/vertical cards.
   - "+ Create Team" button.

3. **`team_detail_screen.dart`:**
   - "🔍 Search by Mobile / Name" Tab: மொபைல் எண் உள்ளிட்டு தேடி உடனடியாக அணியில் சேர்த்தல்.
   - "➕ Register New Player" Tab: ஆப்பில் இல்லாத புதிய வீரருக்கு பெயர் + எண் கொடுத்து சேர்த்தல்.

---

## 🚀 செயல்படுத்தும் படிநிலைகள் (Execution Checklist)
- [x] Create `IMPLEMENTATION_PLAN.md`
- [ ] Update `update_db_v5.php` & DB columns for `owner_id`, `city`
- [ ] Implement `check_name`, `create_user_team`, `my_teams` in `api/team_ops.php`
- [ ] Implement Mobile Phone / Name search in `api/search_ops.php`
- [ ] Update `mobile_app/lib/core/api_service.dart` with new methods
- [ ] Update `mobile_app/lib/features/team/team_create_screen.dart` with Availability Checker
- [ ] Update `mobile_app/lib/features/player/player_profile_screen.dart` with "My Teams"
- [ ] Update `mobile_app/lib/features/team/team_detail_screen.dart` with Phone Number Search Dialog
- [ ] Verify Flutter syntax & test end-to-end
