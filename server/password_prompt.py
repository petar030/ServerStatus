import getpass
import re
import bcrypt

def valid_password(password):
    return (
        len(password) >= 8 and
        re.search(r"[A-Z]", password) and
        re.search(r"[a-z]", password) and
        re.search(r"\d", password) and
        re.search(r"[!@#$%^&*(),.?\":{}|<>]", password)
    )

while True:
    password = getpass.getpass("Enter password: ")
    if valid_password(password):
        break
    print("Password must be at least 8 characters long and include an uppercase letter, lowercase letter, digit, and special character.")

hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
print("Hashed password:", hashed.decode())
