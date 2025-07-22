import { Fragment } from 'react';
import StatusGrid from '../StatusGrid/StatusGrid';
import Spinner from '../Spinner/Spinner';
import './StatusTable.css';

function StatusTable({ statuses, domainUrls, urlToTitleDataMap }) {
  /** derives the title for the status based on the url
   * @param {string} url
   * @returns {string} derivedTitle */
  function deriveTitle(endpoint) {
    return urlToTitleDataMap[endpoint] || endpoint.replaceAll('/', '');
  }

  /** derives a shortened url:
   * for example: https://portal.pedscommons.org becomes portal.pedscommons.org */
  function shortenUrl(url) {
    return url.replace('https://', '');
  }

  return (
    <>
      {statuses.length === 0 && <Spinner />}
      {statuses.length > 0 && (
        <div className='status-page-container'>
          {domainUrls.map((domainUrl, idx) => (
            <Fragment key={idx}>
              <h3 className='title'> Status for {shortenUrl(domainUrl)}: </h3>
              <StatusGrid
                statuses={statuses}
                filterUrl={domainUrl}
                deriveTitle={deriveTitle}
              />
            </Fragment>
          ))}
        </div>
      )}
    </>
  );
}
export default StatusTable;
