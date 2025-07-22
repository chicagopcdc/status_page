import './Banner.css';
import Icon from '../Icon/Icon';
import Spinner from '../Spinner/Spinner';

function Banner({ siteStatus, bannerConfig }) {
  return (
    <div
      className='banner'
      style={{ backgroundColor: bannerConfig.colors[siteStatus] }}>
      {siteStatus !== 'idle' && <Icon status={siteStatus} />}
      <h2> {bannerConfig.message[siteStatus]} </h2>
      {siteStatus === 'idle' && <Spinner className='spinner' />}
    </div>
  );
}
export default Banner;
