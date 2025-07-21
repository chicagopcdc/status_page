import './Banner.css';
import Icon from '../Icon/Icon';

function Banner({ siteStatus, bannerConfig }) {
  return (
    <div
      className='banner'
      style={{ backgroundColor: bannerConfig.colors[siteStatus] }}>
      {siteStatus !== 'idle' && <Icon status={siteStatus} />}
      <h2> {bannerConfig.message[siteStatus]} </h2>
    </div>
  );
}
export default Banner;
