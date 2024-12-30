#!/bin/bash

# File to store expenses
data_file="expenses.txt"

# Function to add an expense
add_expense() {
    local date
    local category
    local amount
    local description

    # Use Zenity dialogs for input
    date=$(zenity --calendar --title="Select Date" --text="Choose the date of the expense" --date-format="%Y-%m-%d") || return
    category=$(zenity --entry --title="Expense Category" --text="Enter the category (e.g., Food, Transport, etc.):") || return
    amount=$(zenity --entry --title="Expense Amount" --text="Enter the amount spent:" --entry-text="0") || return
    description=$(zenity --entry --title="Expense Description" --text="Enter a short description:") || return

    # Append to the data file
    echo "$date|$category|$amount|$description" >> "$data_file"

    zenity --info --text="Expense added successfully!"
}

# Function to view expenses
view_expenses() {
    local filter_option
    local filtered_data

    # Choose how to filter expenses
    filter_option=$(zenity --list --radiolist --title="View Expenses" \
        --column="Select" --column="Filter By" \
        TRUE "All" FALSE "Category" FALSE "Date") || return

    if [ "$filter_option" = "All" ]; then
        filtered_data=$(cat "$data_file")
    elif [ "$filter_option" = "Category" ]; then
        local category
        category=$(zenity --entry --title="Filter by Category" --text="Enter the category to filter:") || return
        filtered_data=$(grep "|$category|" "$data_file")
    elif [ "$filter_option" = "Date" ]; then
        local date
        date=$(zenity --calendar --title="Filter by Date" --text="Choose the date:" --date-format="%Y-%m-%d") || return
        filtered_data=$(grep "^$date|" "$data_file")
    fi

    # Show the filtered data
    if [ -z "$filtered_data" ]; then
        zenity --info --text="No matching expenses found."
    else
        zenity --text-info --title="Expenses" --width=600 --height=400 --filename=<(echo "$filtered_data")
    fi
}

# Function to show the main menu
main_menu() {
    while true; do
        choice=$(zenity --list --title="Expense Tracker" --text="Choose an option:" \
            --column="Option" --column="Description" \
            "1" "Add Expense" \
            "2" "View Expenses" \
            "3" "Exit") || break

        case $choice in
            1) add_expense ;;
            2) view_expenses ;;
            3) exit 0 ;;
            *) zenity --error --text="Invalid option selected." ;;
        esac
    done
}

# Initialize the app
if [ ! -f "$data_file" ]; then
    touch "$data_file"
fi

main_menu
