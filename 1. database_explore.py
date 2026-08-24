try:
    import pyodbc
except ModuleNotFoundError:
    raise SystemExit(
        "pyodbc is not installed in this Python environment.\n"
        "Install it with:\n"
        "  .\\.venv\\Scripts\\python.exe -m pip install pyodbc\n"
        "Then run this script again."
    )

SERVER = r"RAKESH\RAKESHSQLEXPRESS"
DATABASE = "Retail Intelligence"


def get_connection():
    conn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )
    return conn


def get_table_list(conn):
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_SCHEMA, TABLE_NAME;
        """
    )
    return cursor.fetchall()


def get_row_counts(conn):
    cursor = conn.cursor()
    tables = get_table_list(conn)
    row_counts = []

    for schema, table in tables:
        query = f"SELECT COUNT(*) FROM [{schema}].[{table}]"
        cursor.execute(query)
        count = cursor.fetchone()[0]
        row_counts.append((schema, table, count))

    return row_counts


def get_schema(conn):
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'dbo'
        ORDER BY TABLE_NAME, ORDINAL_POSITION;
        """
    )
    return cursor.fetchall()


def get_sample_rows(conn, table_name, limit=5):
    cursor = conn.cursor()
    query = f"SELECT TOP {limit} * FROM dbo.[{table_name}]"
    cursor.execute(query)
    columns = [column[0] for column in cursor.description]
    return columns, cursor.fetchall()


def main():
    conn = get_connection()
    cursor = conn.cursor()

    print("Connecting to database...")
    print(f"Server: {SERVER}")
    print(f"Database: {DATABASE}")
    print("=" * 80)

    tables = get_table_list(conn)
    print("TABLES:")
    for schema, table in tables:
        print(f"- {schema}.{table}")
    print("=" * 80)

    print("ROW COUNTS:")
    for schema, table, count in get_row_counts(conn):
        print(f"{schema}.{table}: {count}")
    print("=" * 80)

    print("SCHEMA:")
    schema_rows = get_schema(conn)
    current_table = None
    for table_name, column_name, data_type, is_nullable in schema_rows:
        if current_table != table_name:
            current_table = table_name
            print(f"\n{table_name}")
        nullable = "NULL" if is_nullable == "YES" else "NOT NULL"
        print(f"  - {column_name}: {data_type} ({nullable})")
    print("=" * 80)

    print("SAMPLE ROWS:")
    for schema, table in tables:
        print(f"\n{schema}.{table}")
        columns, rows = get_sample_rows(conn, table)
        print(" | ".join(columns))
        for row in rows:
            print(" | ".join(
                str(value) if value is not None else "NULL" for value in row))
        print("-" * 60)

    conn.close()


if __name__ == "__main__":
    main()
