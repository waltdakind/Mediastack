import sqlite3

db_path = r'C:\Users\waltd\OneDrive\Mediastack\config\jellyfin\data\data\jellyfin.db'
con = sqlite3.connect(db_path)
cur = con.cursor()
cur.execute("UPDATE Preferences SET Value = Value || ',09790ec4-c971-2e6d-fb09-61f34680b352' WHERE Value LIKE '%f137a2dd-21bb-c1b9-9aa5-c0f6bf02a805%' AND Value NOT LIKE '%09790ec4-c971-2e6d-fb09-61f34680b352%'")
con.commit()
print("Preferences rows updated:", cur.rowcount)
con.close()
