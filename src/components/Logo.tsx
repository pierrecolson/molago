import styles from './Logo.module.css';

export default function Logo() {
  return (
    <div className={styles.logo}>
      <img className={styles.mark} src="/logo.svg" alt="Molago" />
    </div>
  );
}
