import styles from './Logo.module.css';

export default function Logo() {
  return (
    <div className={styles.logo}>
      <svg className={styles.mark} viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect width="120" height="120" rx="24" fill="#E07A5F" />
        <path
          d="M38 44h6v32h-6V44zm10 0h6v14h14V44h6v32h-6V64H54v12h-6V44z"
          fill="white"
        />
        <path
          d="M50 86h20M38 92h44"
          stroke="white"
          strokeWidth="5.5"
          strokeLinecap="round"
        />
      </svg>
      <span className={styles.text}>Molago</span>
    </div>
  );
}
