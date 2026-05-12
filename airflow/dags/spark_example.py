from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'ldp',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'spark_iceberg_example',
    default_args=default_args,
    description='Example Spark job with Iceberg',
    schedule=timedelta(days=1),  # Use 'schedule' instead of deprecated 'schedule_interval'
    catchup=False,
) as dag:

    spark_job = SparkSubmitOperator(
        task_id='run_spark_job',
        application='/path/to/your/job.py',
        conn_id='spark_default',
        conf={
            'spark.jars.packages': 'org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0',
            'spark.sql.catalog.local': 'org.apache.iceberg.spark.SparkCatalog'
        },
    )