import './StatusGrid.css';
import Icon from '../Icon/Icon';
import Spinner from '../Spinner/Spinner';

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
            {status.status !== 'idle' && (
              <Icon className='icon' status={status.status} />
            )}
            {status.status === 'idle' && (
              <Spinner text='loading status' width='30' />
            )}
          </div>
        ))}
    </div>
  );
}
export default StatusGrid;
