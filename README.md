# Status Page

This app implements a status page for several portal.pedscommons.org and gearbox.pedscommons.org endspoints. The app fetches from each endpoint status from the backend and displays whether an endpoint has no issues, is under maintenance, or has an outage (corresponding to the status strings `success`, `maintenance`, and `fail`).

This app uses vite with the Javascript variant of React.

## Getting Started 

`npm install` when opening the repo for the first time

`npm run dev` to start the development server

## Prerequisites

This Status Page requires the following to run:

- [Node.js v20.17.0](https://nodejs.org/en/download)
- [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

## Configuration

Configuration data is located at `config/config.json`. Currently, the file configures which endpoint statuses are fetched (hostnames), what their display names are (urlToTitleDataMap), and the color and message of the banner (bannerConfig). 
