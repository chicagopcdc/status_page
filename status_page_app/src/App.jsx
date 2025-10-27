import Legend from './components/Legend/Legend';
import StatusTable from './components/StatusTable/StatusTable';
import Banner from './components/Banner/Banner';
import config from '../config/config.json';
import { useState, useEffect } from 'react';

function App() {
  const [siteStatus, setSiteStatus] = useState('idle');
  // sets the status of the whole site to 'idle', 'success', or 'fail'
  const { hostnames, bannerConfig, urlToTitleDataMap } = config;

  /** Returns the initial statuses state, with status='idle' for all endpoints,
   * indicating that a status is still being loaded. */
  function initStatuses() {
    const results = [];
    for (const [url, endpoints] of Object.entries(hostnames)) {
      for (const endpoint of endpoints) {
        results.push({ url: url, endpoint: endpoint, status: 'idle' });
      }
    }
    return results;
  }
  const domainUrls = Object.keys(hostnames);
  const initialStatuses = initStatuses();
  const [statuses, setStatuses] = useState(initialStatuses);
  // sets the statuses array, which represents statuses of endpoints

  /**
   * Fetches the status of an endpoint like 'user/' with a base url like
   * 'https://portal.pedscommons.org'.
   * This function returns a string status: 'success', 'fail', or 'maintenance',
   * corresponding to the different statuses in the Legend.
   *
   * Currently, the function returns 'success' if response.status = 200,
   * 'maintenance' if the json body contains a payload like
   * {“status”: “maintenance”}, and 'fail' if an error is thrown, if
   * response.status != 200, or if the fetch request
   * times out (3 seconds).
   *
   * @param {string} url
   * @param {string} endpoint */
  async function fetchStatus(url, endpoint) {
    const rightTrimUrl = url.replace(/\/$/, '');
    const leftTrimEndpoint = endpoint.replace(/^\//, '');
    const endpoint_url = `${rightTrimUrl}/${leftTrimEndpoint}_status`;
    try {
      const response = await fetch(endpoint_url, {
        method: 'GET',
        signal: AbortSignal.timeout(3000)
      });

      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        const json = await response.json();
        if (json.status && json.status.toLowerCase() === 'maintenance') {
          return 'maintenance';
        }
      }

      return response.status === 200 ? 'success' : 'fail';
    } catch (error) {
      console.error(`Fetch failed: ${error}`);
      return 'fail';
    }
  }
  // statuses are loaded individually as they are fetched
  useEffect(() => {
    const checkStatus = async () => {
      let allStatuses = [];

      for (const [url, endpoints] of Object.entries(hostnames)) {
        for (const endpoint of endpoints) {
          const asyncStatus = (async () => {
            const status = await fetchStatus(url, endpoint);
            const newStatus = { url, endpoint, status };

            setStatuses((prev) =>
              prev.map((s) =>
                s.url === url && s.endpoint === endpoint ? newStatus : s
              )
            );
            return newStatus;
          })();

          allStatuses.push(asyncStatus);
        }
      }

      const overallSite = await Promise.all(allStatuses);
      const allSuccessful = overallSite.every((s) => s.status === 'success');
      const anyMaintenance = overallSite.some(
        (s) => s.status === 'maintenance'
      );

      setSiteStatus(
        allSuccessful ? 'success' : anyMaintenance ? 'maintenance' : 'fail'
      );
    };

    checkStatus();
  }, []);

  return (
    <>
      <Banner siteStatus={siteStatus} bannerConfig={bannerConfig} />
      <Legend />
      <hr />
      <StatusTable
        domainUrls={domainUrls}
        statuses={statuses}
        urlToTitleDataMap={urlToTitleDataMap}
      />
    </>
  );
}

export default App;

