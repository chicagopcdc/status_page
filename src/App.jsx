import Legend from './components/Legend/Legend';
import StatusTable from './components/StatusTable/StatusTable';
import Banner from './components/Banner/Banner';
import config from '../config/config.json';
import { useState, useEffect } from 'react';

function App() {
  const [siteStatus, setSiteStatus] = useState('idle');
  // sets the status of the whole site to 'idle', 'success', or 'fail'
  const [statuses, setStatuses] = useState([]);
  // sets the statuses array, which represents statuses of endpoints
  const { hostnames, bannerConfig, urlToTitleDataMap } = config;

  /** Fetches the status of an endpoint like 'user/' with a base url like
   * 'https://portal.pedscommons.org'.
   * This function returns a string status: 'success', 'fail', or 'maintenance',
   * corresponding to the different statuses in the Legend.
   *
   * Currently, the function returns 'success' if response.status = 200, 'fail' if
   * an error is thrown or if response.status != 200, and 'maintenance' if
   * the json body contains a payload like {“status”: “maintenance”}.
   * @param {string} url
   * @param {string} endpoint */
  async function fetchStatus(url, endpoint) {
    const rightTrimUrl = url.replace(/\/$/, '');
    const leftTrimEndpoint = endpoint.replace(/^\//, '');
    const endpoint_url = `${rightTrimUrl}/${leftTrimEndpoint}_status`;
    try {
      const response = await fetch(endpoint_url, { method: 'GET' });

      try {
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          const json = await response.json();
          if (json.status && json.status.toLowerCase() === 'maintenance') {
            return 'maintenance';
          }
        }
      } catch {}
      if (response.status === 200) {
        return 'success';
      } else {
        return 'fail';
      }
    } catch (error) {
      console.error(`Fetch failed: ${error}`);
      return 'fail';
    }
  }

  /** returns an array of objects like [{ url: 'url.com', endpoint: 'endpoint', status: 'success' }, ...]*/
  const checkStatus = async () => {
    let result = [];

    for (const [url, endpoints] of Object.entries(hostnames)) {
      for (const endpoint of endpoints) {
        const status = await fetchStatus(url, endpoint);
        result.push({
          url: url,
          endpoint: endpoint,
          status: status
        });
      }
    }
    return result;
  };

  useEffect(() => {
    const fetchAllStatuses = async () => {
      const results = await checkStatus();
      setStatuses(results);
    };
    fetchAllStatuses();
  }, []);

  useEffect(() => {
    if (statuses.length === 0) return;
    const allSuccessful = statuses.every((s) => s.status === 'success');
    const anyMaintenance = statuses.some((s) => s.status === 'maintenance');
    setSiteStatus(
      allSuccessful ? 'success' : anyMaintenance ? 'maintenance' : 'fail'
    );
  }, [statuses]);

  const domainUrls = Object.keys(hostnames);

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
