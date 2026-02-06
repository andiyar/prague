# Dad's Prague Trip Dashboard

A family dashboard for tracking Dad's EAPC conference trip to Prague. Features two views: a detailed family view and a kid-friendly view.

## Setup Instructions

### 1. Set up Supabase

1. Go to your Supabase project: https://dyxupzbyssvcxjppipnl.supabase.co
2. Open the **SQL Editor**
3. Run `sql/schema.sql` first (creates tables and policies)
4. Run `sql/seed.sql` second (populates trip schedule)

### 2. Deploy to GitHub Pages

1. Push this `site` folder contents to your `andiyar/prague` repo
2. Go to repo Settings → Pages
3. Set Source to "Deploy from a branch"
4. Select `main` branch and `/ (root)` folder
5. Save

Your site will be live at: https://andiyar.github.io/prague

### 3. (Optional) Custom Domain

1. In GitHub Pages settings, add your custom domain
2. Create a CNAME record pointing to `andiyar.github.io`

## File Structure

```
site/
├── index.html      # Main HTML with both views
├── app.js          # All JavaScript logic
├── README.md       # This file
└── sql/
    ├── schema.sql  # Database schema
    └── seed.sql    # Trip schedule data
```

## Features

### Family View
- Current status banner with emoji and text
- Timezone clocks (Sydney, Prague, Dad's local)
- Weather widget for Dad's current location
- Countdown to return
- Flight cards with progress bars
- Interactive map showing Dad's location
- Contact information

### Kids View
- Big friendly emoji and text
- Interactive map with animated plane during flights
- "X sleeps until Dad's home" countdown

## Updating Status

During the trip, use Claude Code to update status:

```
"Update status: just landed in Dubai"
"Update status: at the hotel now"
"Clear override"
```

Claude Code will read the credentials from `claude.md` and call the Supabase API.

## Tech Stack

- **Frontend**: Vanilla HTML/CSS/JS
- **Maps**: Leaflet + OpenStreetMap
- **Weather**: Open-Meteo API
- **Database**: Supabase
- **Hosting**: GitHub Pages
