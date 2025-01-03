#!/bin/bash

# Ensure necessary CSV files exist
initialize_files() {
    if [[ ! -f users.csv ]]; then
        echo "Username,Password" >users.csv
    fi
}

# Function for Login
login() {
    username=$(zenity --entry --title="🔑 Login" --text="👤 Enter your username:" --window-icon="info")
    password=$(zenity --password --title="🔑 Login" --text="🔒 Enter your password:" --window-icon="info")

    if grep -q "^$username,$password$" users.csv; then
        zenity --info --text="🎉 Login successful! Welcome, $username." --title="✅ Success" --window-icon="info"
        logged_in_user="$username"
        initialize_user_expenses
        return 0
    else
        zenity --error --text="❌ Invalid username or password. Please try again." --title="⚠️ Login Failed" --window-icon="error"
        return 1
    fi
}

# Function for Signup
signup() {
    user_data=$(zenity --forms --title="✍️ Sign Up" --text="Create a new account" \
        --add-entry="👤 Username" \
        --add-password="🔒 Password" \
        --add-password="🔒 Confirm Password" \
        --window-icon="info")

    if [[ $? -eq 0 ]]; then
        username=$(echo "$user_data" | cut -d '|' -f 1)
        password=$(echo "$user_data" | cut -d '|' -f 2)
        confirm_password=$(echo "$user_data" | cut -d '|' -f 3)

        if [[ "$password" != "$confirm_password" ]]; then
            zenity --error --text="❌ Passwords do not match. Please try again." --title="⚠️ Error" --window-icon="error"
            return
        fi

        if grep -q "^$username," users.csv; then
            zenity --error --text="❌ Username already exists. Please choose another." --title="⚠️ Error" --window-icon="error"
            return
        fi

        echo "$username,$password" >>users.csv
        touch "expenses_$username.csv"
        echo "Description,Amount,Date" >"expenses_$username.csv"
        zenity --info --text="🎉 Account created successfully!" --title="✅ Sign Up" --window-icon="info"
    fi
}

# Initialize the user's expenses file
initialize_user_expenses() {
    if [[ ! -f "expenses_$logged_in_user.csv" ]]; then
        echo "Description,Amount,Date" >"expenses_$logged_in_user.csv"
    fi
}

# Function to Add Expense
add_expense() {
    expense_data=$(zenity --forms --title="💸 Add Expense" --text="Enter expense details below:" \
        --add-entry="📝 Description" \
        --add-entry="💰 Amount" \
        --add-calendar="📅 Date" \
        --window-icon="info")
    
    if [[ $? -eq 0 ]]; then
        description=$(echo "$expense_data" | cut -d '|' -f 1)
        amount=$(echo "$expense_data" | cut -d '|' -f 2)
        date=$(echo "$expense_data" | cut -d '|' -f 3)
        echo "$description,$amount,$date" >>"expenses_$logged_in_user.csv"
        zenity --info --text="✅ Expense added successfully!" --title="Success" --window-icon="info"
    fi
}

# Function to View Expenses
view_expenses() {
    if [[ ! -s "expenses_$logged_in_user.csv" || $(wc -l <"expenses_$logged_in_user.csv") -le 1 ]]; then
        zenity --warning --text="📂 No expenses found. Please add some expenses first." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    zenity --list --title="📋 View Expenses" --text="Here are your recorded expenses:" \
        --column="📝 Description" --column="💰 Amount" --column="📅 Date" \
        $(tail -n +2 "expenses_$logged_in_user.csv" | awk -F, '{print $1 " " $2 " " $3}' | tr '\n' ' ') --window-icon="info"
}

# Function to Export Report
export_report() {
    save_path=$(zenity --file-selection --save --title="💾 Export Report" --filename="expenses_${logged_in_user}_report.csv" --window-icon="info")
    if [[ $? -eq 0 ]]; then
        cp "expenses_$logged_in_user.csv" "$save_path"
        zenity --info --text="✅ Report exported successfully to $save_path!" --title="Success" --window-icon="info"
    fi
}

# Main Menu
main_menu() {
    while true; do
        user_action=$(zenity --list --title="🏠 Main Menu" --text="Choose an action:" \
            --column="🚀 Actions" \
            "💸 Add Expense" "📋 View Expenses" "💾 Export Report" "🔒 Logout" --window-icon="info")

        case "$user_action" in
        "💸 Add Expense")
            add_expense
            ;;
        "📋 View Expenses")
            view_expenses
            ;;
        "💾 Export Report")
            export_report
            ;;
        "🔒 Logout")
            zenity --question --text="Are you sure you want to logout?" --title="🔒 Logout" --window-icon="question"
            if [[ $? -eq 0 ]]; then
                break
            fi
            ;;
        *)
            zenity --error --text="❌ Invalid selection. Please try again." --title="⚠️ Error" --window-icon="error"
            ;;
        esac
    done
}

# Main Script Execution
initialize_files
while true; do
    user_action=$(zenity --list --title="📊 Expense Tracker" --text="Welcome to Expense Tracker! Please choose an option:" \
        --column="🚀 Actions" \
        "🔑 Login" "✍️ Sign Up" "❌ Exit" --window-icon="info")

    case "$user_action" in
    "🔑 Login")
        if login; then
            main_menu
        fi
        ;;
    "✍️ Sign Up")
        signup
        ;;
    "❌ Exit")
        zenity --question --text="Are you sure you want to exit?" --title="❌ Exit" --window-icon="question"
        if [[ $? -eq 0 ]]; then
            break
        fi
        ;;
    *)
        zenity --error --text="❌ Invalid selection. Please try again." --title="⚠️ Error" --window-icon="error"
        ;;
    esac
done
