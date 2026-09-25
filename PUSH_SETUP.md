# Push notifications setup checklist

Code is wired end-to-end. **Real device delivery still needs Firebase project files from you.**

## What you must provide

1. **`google-services.json`**  
   Firebase Console → Project settings → Your apps → Android (`com.machakoseoc.mobileapp`) → Download  
   Place at: `C:\Users\Nccg\android\app\google-services.json`

2. **`GoogleService-Info.plist`** (iOS only)  
   Place at: `C:\Users\Nccg\ios\Runner\GoogleService-Info.plist`

3. **Firebase service-account JSON** (same project)  
   Project settings → Service accounts → Generate new private key  
   In web admin (SUPER_ADMIN): **Admin → Notifications → Push** → paste → **Save** → **Test connection** → **Set as active**

Drop the files into chat or copy them into those paths, then say when ready and we can verify a device test.

## What was implemented

### Mobile (`C:\Users\Nccg`)
- Safe init when Firebase config is missing (app still runs)
- Android 13+ notification permission + iOS permission
- Token register / refresh / logout `deleteToken` + `DELETE /notifications/token`
- Richer tap payload (`type|taskId|caseNumber|status`) → Assignment tab
- **Crew tab → bell icon** = `POST /notifications/test` (self-test)

### Backend (`machakos-web`)
- Push data includes `taskId`
- New stop → `TASK_ROUTE_CHANGED` FCM (plus existing sockets)
- `POST /notifications/test` — crew self-test
- `POST /settings/push-gateway/send-test` `{ userId }` — admin device test
- Clear errors when gateway inactive / no token / FCM reject

## Verify after Firebase files are in place

1. Restart backend (`C:\Users\USER\machakos-web\backend\.\dev.cmd`)
2. Rebuild Flutter (config is build-time):  
   `flutter run --dart-define=API_URL=http://192.168.100.92:3000`
3. Log in as DRIVER/EMT/NURSE → allow notifications
4. Crew tab → tap bell → expect “NMS EOC test”
5. Or admin: paste user UUID → **Send device test**
6. Dispatch a case → expect `New case: …` on phone
