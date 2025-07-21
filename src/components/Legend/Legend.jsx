import Icon from '../Icon/Icon';
import './Legend.css';

function Legend() {
  return (
    <div className='legend-container'>
      <h2> Legend </h2>
      <div className='item-pair'>
        <p> no issues </p>
        <Icon status='success' />
      </div>
      <div className='item-pair'>
        <p> under maintenance </p>
        <Icon status='maintenance' />
      </div>
      <div className='item-pair'>
        <p> outage </p>
        <Icon status='fail' />
      </div>
    </div>
  );
}
export default Legend;
