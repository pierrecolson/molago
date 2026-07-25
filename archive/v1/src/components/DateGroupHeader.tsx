import styles from './DateGroupHeader.module.css';

interface DateGroupHeaderProps {
  label: string;
}

export default function DateGroupHeader({ label }: DateGroupHeaderProps) {
  return (
    <div className={styles.header}>
      <span className={styles.label}>{label}</span>
    </div>
  );
}
