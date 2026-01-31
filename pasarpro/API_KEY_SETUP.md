# PasarPro - Getting Your Gemini API Key

## Step 1: Go to Google AI Studio
Visit: https://aistudio.google.com/

## Step 2: Sign in with Google Account
Use your Google account (any Gmail will work)

## Step 3: Get API Key
1. Click "Get API key" in the top right
2. Click "Create API key"
3. Select "Create API key in new project" (or choose existing project)
4. Copy the API key (starts with `AIza...`)

## Step 4: Add to .env File
1. Open `pasarpro/.env` file
2. Replace `your_api_key_here` with your actual API key:
   ```
   GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
3. Save the file

## Important Notes
- ✅ FREE tier: 10 requests/min, 250 requests/day
- ✅ No credit card required
- ⚠️ Never commit .env file to GitHub (already in .gitignore)
- ⚠️ Don't share your API key publicly

## Testing Your API Key
Run the app and try capturing a photo. If you see errors about API key, double-check:
1. API key is correctly copied (no extra spaces)
2. .env file is in the `pasarpro/` directory (not in `pasarpro/lib/`)
3. You've run `flutter pub get` after adding the .env to assets

## Rate Limits
- **Free tier**: 10 RPM, 250 RPD
- If you hit limits during testing, wait a minute or use a different Google account for a new API key
