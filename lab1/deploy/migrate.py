#!/usr/bin/env python3
import sys
import yaml
import psycopg2
import re

def parse_jdbc_url(url):
    match = re.match(r'jdbc:postgresql://([^:/]+):(\d+)/(.+)', url)
    if not match:
        raise ValueError(f"Cannot parse JDBC URL: {url}")
    return match.group(1), int(match.group(2)), match.group(3)

def main():
    config_path = '/etc/mywebapp/config.yaml'
    with open(config_path) as f:
        config = yaml.safe_load(f)

    ds = config['spring']['datasource']
    host, port, dbname = parse_jdbc_url(ds['url'])

    conn = psycopg2.connect(host=host, port=port, dbname=dbname,
                            user=ds['username'], password=ds['password'])
    conn.autocommit = True
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id         BIGSERIAL PRIMARY KEY,
            name       VARCHAR(255) NOT NULL,
            quantity   INTEGER NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
    """)

    cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_items_id ON items(id)
    """)

    cur.close()
    conn.close()
    print("Migration complete")

if __name__ == '__main__':
    main()
