import noIssueImg from '../../assets/icons/good.png';
import outageImg from '../../assets/icons/outage.png';
import maintenanceImg from '../../assets/icons/maintenance.png';

/** @param {string} status - the status prop is derived from statuses[index].status, 
 and has string value 'success', 'fail', or 'maintenance', as described by 
 fetchStatus() in App.jsx */
function Icon({ status }) {
  return (
    <img
      src={
        status === 'success'
          ? noIssueImg
          : status === 'fail'
          ? outageImg
          : maintenanceImg
      }
      alt={`the ${
        status === 'success'
          ? 'green checkmark'
          : status === 'fail'
          ? 'outage'
          : 'maintenance'
      } symbol`}
      width={30}
      height={30}
    />
  );
}
export default Icon;
