# PasarPro - Getting Your Gemini API Key

## Step 1: Create Account (New user get free 300USD credits) and login into Google Cloud Console
Visit: https://console.cloud.google.com/

## Step 2: Go to Vertex AI Studio and create API Key
Visit: https://console.cloud.google.com/vertex-ai/studio/settings/

## Step 3: Add to .env File
1. Open `pasarpro/.env` file
2. Replace `your_api_key_here` with your actual API key:
   ```
   VERTEX_API_KEY: AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
3. Save the file

## Important Notes
- ⚠️ Never commit .env file to GitHub (already in .gitignore)
- ⚠️ Don't share your API key publicly

## Testing Your API Key
Run the app and try capturing a photo. If you see errors about API key, double-check:
1. API key is correctly copied (no extra spaces)
2. .env file is in the `pasarpro/` directory (not in `pasarpro/lib/`)
3. You've run `flutter pub get` after adding the .env to assets
