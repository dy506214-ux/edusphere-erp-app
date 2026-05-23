import socket
import psycopg2
import sys

def get_ipv4_addresses(hostname):
    try:
        # Get all address info
        addr_info = socket.getaddrinfo(hostname, None)
        # Extract only IPv4 addresses
        ipv4_addresses = [info[4][0] for info in addr_info if info[0] == socket.AF_INET]
        return list(set(ipv4_addresses))
    except Exception as e:
        print(f"Error resolving {hostname}: {e}")
        return []

def main():
    regions = [
        "ap-south-1",      # Mumbai
        "ap-southeast-1",  # Singapore
        "ap-northeast-1",  # Tokyo
        "ap-northeast-2",  # Seoul
        "us-east-1",       # N. Virginia
        "us-east-2",       # Ohio
        "us-west-1",       # N. California
        "us-west-2",       # Oregon
        "eu-central-1",    # Frankfurt
        "eu-west-1",       # Ireland
        "eu-west-2",       # London
        "eu-west-3",       # Paris
        "sa-east-1",       # São Paulo
        "ca-central-1",    # Canada
        "ap-southeast-2",  # Sydney
    ]
    
    password = "akshitsha84"
    project_ref = "xernedkpgdrvjokokdoa"
    username = f"postgres.{project_ref}"
    
    print(f"Starting scan to find active region for project {project_ref}...")
    
    for region in regions:
        hostname = f"aws-0-{region}.pooler.supabase.com"
        ips = get_ipv4_addresses(hostname)
        if not ips:
            print(f"Could not resolve IPv4 for {region}")
            continue
            
        print(f"Checking region: {region} (resolved IPs: {ips})")
        for ip in ips:
            db_uri = f"postgresql://{username}:{password}@{ip}:6543/postgres?connect_timeout=3"
            try:
                conn = psycopg2.connect(db_uri)
                print(f"\nSUCCESS!!! Found working regional pooler!")
                print(f"Region: {region}")
                print(f"Resolved IP: {ip}")
                print(f"Connection String: postgresql://{username}:PASSWORD@{hostname}:6543/postgres?pgbouncer=true\n")
                conn.close()
                sys.exit(0)
            except Exception as e:
                err = str(e).strip()
                if "tenant/user" in err or "Tenant or user not found" in err:
                    # This means we reached the pooler, but this is the wrong region for the tenant
                    print(f"  Wrong region: {region} pooler reached, but tenant not found here.")
                    break # Skip other IPs for this region since they point to the same pooler cluster
                else:
                    print(f"  Connection to {ip} failed: {err[:100]}")

    print("\nCompleted scan. Could not connect to any regional pooler.")
    sys.exit(1)

if __name__ == "__main__":
    main()
