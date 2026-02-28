import styles from './Logo.module.css';

export default function Logo() {
  return (
    <div className={styles.logo}>
      <div className={styles.mark}>몰</div>
      <span className={styles.text}>Molago</span>
    </div>
  );
}
