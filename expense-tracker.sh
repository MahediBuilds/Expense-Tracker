#!/bin/bash

LOG_FILE="expense_tracker.log"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

initialize_files() {
    log_message "Initializing users.csv if not present."
    if [[ ! -f users.csv ]]; then
        echo "Username,Password" >users.csv
    fi
}

login() {
    log_message "User attempting login."
    username=$(zenity --entry --title="🔑 Login" --text="👤 Enter your username:" --window-icon="info")
    password=$(zenity --password --title="🔑 Login" --text="🔒 Enter your password:" --window-icon="info")

    if grep -q "^$username,$password$" users.csv; then
        log_message "Login successful for user: $username"
        zenity --info --text="🎉 Login successful! Welcome, $username." --title="✅ Success" --window-icon="info"
        logged_in_user="$username"
        initialize_user_expenses
        return 0
    else
        log_message "Login failed for user: $username"
        zenity --error --text="❌ Invalid username or password. Please try again." --title="⚠️ Login Failed" --window-icon="error"
        return 1
    fi
}

signup() {
    log_message "User attempting signup."
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
            log_message "Signup failed: passwords do not match."
            zenity --error --text="❌ Passwords do not match. Please try again." --title="⚠️ Error" --window-icon="error"
            return
        fi

        if grep -q "^$username," users.csv; then
            log_message "Signup failed: username already exists."
            zenity --error --text="❌ Username already exists. Please choose another." --title="⚠️ Error" --window-icon="error"
            return
        fi

        echo "$username,$password" >>users.csv
        touch "expenses_$username.csv"
        echo "Description,Amount,Date" >"expenses_$username.csv"
        log_message "Signup successful for user: $username"
        zenity --info --text="🎉 Account created successfully!" --title="✅ Sign Up" --window-icon="info"
    fi
}

initialize_user_expenses() {
    log_message "Initializing expenses file for user: $logged_in_user"
    if [[ ! -f "expenses_$logged_in_user.csv" ]]; then
        echo "Description,Amount,Date" >"expenses_$logged_in_user.csv"
    fi
}

add_expense() {
    log_message "Adding expense for user: $logged_in_user"
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
        log_message "Expense added: $description, $amount, $date"
        zenity --info --text="✅ Expense added successfully!" --title="Success" --window-icon="info"
    fi
}

view_expenses() {
    log_message "Viewing expenses for user: $logged_in_user"
    if [[ ! -s "expenses_$logged_in_user.csv" || $(wc -l <"expenses_$logged_in_user.csv") -le 1 ]]; then
        log_message "No expenses found for user: $logged_in_user"
        zenity --warning --text="📂 No expenses found. Please add some expenses first." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    declare -A month_year_map
    while IFS=',' read -r description amount date; do
        if [[ -n "$description" && -n "$amount" && -n "$date" ]]; then
            month=$(date -d "$date" +"%B" 2>/dev/null || echo "Invalid Date")
            year=$(date -d "$date" +"%Y" 2>/dev/null || echo "Invalid Date")
            if [[ $month != "Invalid Date" && $year != "Invalid Date" ]]; then
                month_year_map["$month"]+="$year "
            fi
        fi
    done < <(tail -n +2 "expenses_$logged_in_user.csv")

    calendar_order=(January February March April May June July August September October November December)
    sorted_months=()
    for month in "${calendar_order[@]}"; do
        if [[ -n "${month_year_map[$month]}" ]]; then
            sorted_months+=("$month")
        fi
    done

    if [[ ${#sorted_months[@]} -eq 0 ]]; then
        log_message "No months found with expenses for user: $logged_in_user"
        zenity --warning --text="No months with expenses found." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    selected_month=$(zenity --list --title="📅 Select Month" --text="Choose a month to view expenses:" \
        --column="Month" "${sorted_months[@]}" --width=300 --height=400 --window-icon="calendar")

    if [[ -z "$selected_month" ]]; then
        log_message "No month selected while viewing expenses."
        zenity --info --text="No month selected. Exiting..." --title="ℹ️ Info" --window-icon="info"
        return
    fi

    unique_years=($(printf "%s\n" ${month_year_map[$selected_month]} | tr ' ' '\n' | sort -u))

    if [[ ${#unique_years[@]} -eq 0 ]]; then
        log_message "No years found for $selected_month."
        zenity --warning --text="No years found for $selected_month." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    selected_year=$(zenity --list --title="📅 Select Year" --text="Choose a year to view expenses:" \
        --column="Year" "${unique_years[@]}" --width=300 --height=400 --window-icon="calendar")

    if [[ -z "$selected_year" ]]; then
        log_message "No year selected while viewing expenses."
        zenity --info --text="No year selected. Exiting..." --title="ℹ️ Info" --window-icon="info"
        return
    fi

    display_list=()
    total_spent=0
    while IFS=',' read -r description amount date; do
        if [[ -n "$description" && -n "$amount" && -n "$date" ]]; then
            month=$(date -d "$date" +"%B" 2>/dev/null || echo "Invalid Date")
            year=$(date -d "$date" +"%Y" 2>/dev/null || echo "Invalid Date")
            if [[ "$month" == "$selected_month" && "$year" == "$selected_year" ]]; then
                display_list+=("$description" "₹$amount" "$date")
                total_spent=$(awk "BEGIN {print $total_spent + $amount}")
            fi
        fi
    done < <(tail -n +2 "expenses_$logged_in_user.csv")

    if [[ ${#display_list[@]} -eq 0 ]]; then
        log_message "No expenses found for $selected_month $selected_year."
        zenity --warning --text="No expenses found for $selected_month $selected_year." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    log_message "Displaying expenses for $selected_month $selected_year."
    zenity --list --title="📋 View Expenses" --text="Expenses for $selected_month $selected_year:\n\n💰 Total Spent: ₹$total_spent" \
        --column="📝 Description" --column="💰 Amount" --column="📅 Date" \
        "${display_list[@]}" --width=800 --height=600 --window-icon="info"
}

delete_expense() {
    log_message "Deleting expense for user: $logged_in_user"
    if [[ ! -s "expenses_$logged_in_user.csv" || $(wc -l <"expenses_$logged_in_user.csv") -le 1 ]]; then
        log_message "No expenses found for deletion."
        zenity --warning --text="📂 No expenses found. Please add some expenses first." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    declare -A month_year_map
    while IFS=',' read -r description amount date; do
        if [[ -n "$description" && -n "$amount" && -n "$date" ]]; then
            month=$(date -d "$date" +"%B" 2>/dev/null || echo "Invalid Date")
            year=$(date -d "$date" +"%Y" 2>/dev/null || echo "Invalid Date")
            if [[ $month != "Invalid Date" && $year != "Invalid Date" ]]; then
                month_year_map["$month"]+="$year "
            fi
        fi
    done < <(tail -n +2 "expenses_$logged_in_user.csv")

    calendar_order=(January February March April May June July August September October November December)
    sorted_months=()
    for month in "${calendar_order[@]}"; do
        if [[ -n "${month_year_map[$month]}" ]]; then
            sorted_months+=("$month")
        fi
    done

    if [[ ${#sorted_months[@]} -eq 0 ]]; then
        log_message "No months with expenses found for deletion."
        zenity --warning --text="No months with expenses found." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    selected_month=$(zenity --list --title="📅 Select Month" --text="Choose a month to delete expenses:" \
        --column="Month" "${sorted_months[@]}" --width=300 --height=400 --window-icon="calendar")

    if [[ -z "$selected_month" ]]; then
        log_message "No month selected while deleting."
        zenity --info --text="No month selected. Exiting..." --title="ℹ️ Info" --window-icon="info"
        return
    fi

    mapfile -t unique_years < <(printf "%s\n" "${month_year_map[$selected_month]}" | tr ' ' '\n' | sort -u)

    if [[ ${#unique_years[@]} -eq 0 ]]; then
        log_message "No years found for $selected_month while deleting."
        zenity --warning --text="No years found for $selected_month." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    selected_year=$(zenity --list --title="📅 Select Year" --text="Choose a year to delete expenses:" \
        --column="Year" "${unique_years[@]}" --width=300 --height=400 --window-icon="calendar")

    if [[ -z "$selected_year" ]]; then
        log_message "No year selected while deleting."
        zenity --info --text="No year selected. Exiting..." --title="ℹ️ Info" --window-icon="info"
        return
    fi

    display_list=()
    while IFS=',' read -r description amount date; do
        if [[ -n "$description" && -n "$amount" && -n "$date" ]]; then
            month=$(date -d "$date" +"%B" 2>/dev/null || echo "Invalid Date")
            year=$(date -d "$date" +"%Y" 2>/dev/null || echo "Invalid Date")
            if [[ "$month" == "$selected_month" && "$year" == "$selected_year" ]]; then
                display_list+=("$description|₹$amount|$date")
            fi
        fi
    done < <(tail -n +2 "expenses_$logged_in_user.csv")

    if [[ ${#display_list[@]} -eq 0 ]]; then
        log_message "No expenses found for $selected_month $selected_year while deleting."
        zenity --warning --text="No expenses found for $selected_month $selected_year." --title="⚠️ No Data" --window-icon="warning"
        return
    fi

    selected_expense=$(zenity --list --title="🗑️ Delete Expense" --text="Select an expense to delete:" \
        --column="📝 Description | 💰 Amount | 📅 Date" \
        "${display_list[@]}" --width=800 --height=600 --window-icon="info")

    if [[ -z "$selected_expense" ]]; then
        log_message "No expense selected for deletion."
        zenity --info --text="⚠️ No expense selected. Operation canceled." --title="ℹ️ Info" --window-icon="info"
        return
    fi

    IFS='|' read -r description amount date <<<"$selected_expense"
    description=$(echo "$description" | xargs)
    amount=$(echo "$amount" | sed 's/₹//g' | xargs)
    date=$(echo "$date" | xargs)

    log_message "Deleting expense: $description, $amount, $date"
    awk -F',' -v desc="$description" -v amt="$amount" -v dte="$date" \
        '!(($1 == desc) && ($2 == amt) && ($3 == dte)) { print }' "expenses_$logged_in_user.csv" > temp.csv && mv temp.csv "expenses_$logged_in_user.csv"

    zenity --info --text="✅ Expense deleted successfully!" --title="Success" --window-icon="info"
}

export_report() {
    log_message "Exporting report for user: $logged_in_user"
    save_path=$(zenity --file-selection --save --title="💾 Export Report" --filename="expenses_${logged_in_user}_report.csv" --window-icon="info")
    if [[ $? -eq 0 ]]; then
        cp "expenses_$logged_in_user.csv" "$save_path"
        log_message "Report exported successfully to $save_path"
        zenity --info --text="✅ Report exported successfully to $save_path!" --title="Success" --window-icon="info"
    fi
}

main_menu() {
    while true; do
        log_message "Displaying main menu for user: $logged_in_user"
        user_action=$(zenity --list --title="🏠 Main Menu" --text="Choose an action:" \
            --column="🚀 Actions" \
            "💸 Add Expense" "📋 View Expenses" "🗑️ Delete Expense" "💾 Export Report" "🔒 Logout" --window-icon="info")

        case "$user_action" in
        "💸 Add Expense")
            add_expense
            ;;
        "📋 View Expenses")
            view_expenses
            ;;
        "🗑️ Delete Expense")
            delete_expense
            ;;
        "💾 Export Report")
            export_report
            ;;
        "🔒 Logout")
            zenity --question --text="Are you sure you want to logout?" --title="🔒 Logout" --window-icon="question"
            if [[ $? -eq 0 ]]; then
                log_message "User logged out: $logged_in_user"
                break
            fi
            ;;
        *)
            log_message "Invalid selection in main menu."
            zenity --error --text="❌ Invalid selection. Please try again." --title="⚠️ Error" --window-icon="error"
            ;;
        esac
    done
}

initialize_files
while true; do
    log_message "Displaying initial menu."
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
            log_message "User exited the application."
            break
        fi
        ;;
    *)
        log_message "Invalid selection in initial menu."
        zenity --error --text="❌ Invalid selection. Please try again." --title="⚠️ Error" --window-icon="error"
        ;;
    esac
done
