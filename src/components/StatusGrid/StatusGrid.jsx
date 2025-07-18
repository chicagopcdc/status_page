import './StatusGrid.css';
import Icon from '../Icon/Icon';

function StatusGrid({ statuses, filterUrl, deriveTitle }) {
  return (
    <div className='status-grid'>
      {statuses
        .filter((status) => status.url === filterUrl)
        .map((status) => (
          <div
            key={`${status.url}-${status.endpoint}`}
            className='status-component'>
            <div>
              <p className='component-title'>{deriveTitle(status.endpoint)}</p>
              <p> url path: {status.endpoint} </p>
            </div>
            <Icon status={status.status} />
          </div>
        ))}
    </div>
  );
}
export default StatusGrid;
