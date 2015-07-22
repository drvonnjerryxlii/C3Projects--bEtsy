class UsersController < ApplicationController
  before_action :find_user, only: :products_of_user
  before_action :products_of_user, only: [:index, :show]

  def show
    @user = User.find(params[:id])
    # Product has user_id
    products = Product.where(user_id: @user.id)

    orders_items = [] # array of ActiveRecord::Relations
    products.each do |product|
      # OrderItem has product_id
      orders_items << OrderItem.where(product_id: product.id)
    end

    orders = find_orders(orders_items)
    separate_by_status(orders) # @pending, @paid, @completed, @canceled
    @total_revenue = revenue(orders_items)

    if @paid != []
      # sent inside of an array to match format of orders_items
      @paid_revenue = revenue([OrderItem.where(order_id: @paid.first.id)])
    else
      @paid_revenue = 0
    end

    if @completed != []
      @completed_revenue = revenue([OrderItem.where(order_id: @completed.first.id)])
    else
      @completed_revenue = 0
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id # creates a session - they are logged in
      redirect_to user_path(@user) # WHERE DO WE WANT THIS TO REDIRECT TO?
      # redirect_to root_path # with a message that they successfully created an account?
    else
      error_check_for("username")
      error_check_for("email")
      error_check_for("password")
      error_check_for("password_confirmation")
        # Would we use the flash.now to display the individual errors?
        # Should we reference the individual errors in the views via the instance variable?
      render :new
    end
  end

  def edit
    # PLACE HOLDER - SHINY STUFF THAT ISN'T REQUIRED
  end

  def find_user
    @user = User.find(session[:user_id])
  end

  def products_of_user
    user_products = @user.products.to_a
    @product_ids = []
    user_products.each do |product|
      @product_ids << product.id
    end
    order_items_by_user
  end

  def order_items_by_user
    @order_items = []
    @product_ids.each do |product_id|
      @order_items << OrderItem.where(product_id: product_id)
    end

    if @order_items.count > 1
      return @order_items
    else
      @order_items = nil
    end
  end

  def index
    # if orders.order_items.product_id == user.products.ids
    @orders = []
    if @order_items.nil?
      puts "No Current Orders"
    else
      @order_items.each do |order_item|
        @orders << Order.where(id: order_item.first.order_id)
        # still need to account for qty of order item
        @orders.uniq!
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end

  def nil_flash_errors
    flash.now[:username_error] = nil
    flash.now[:email_error] = nil
    flash.now[:password_error] = nil
    flash.now[:password_confirmation_error] = nil
  end

  # NOTE TO SELF: This should actually be a method inside the views helper.
  # Flash is usually only used for messages at the top of pages.
  # They work for this, but conventionally they are not used like how I am using them here. - Brandi
  def error_check_for(element)
    if @user.errors[element].any?
      flash.now[(element + "_error").to_sym] = (@user.errors.messages[element.to_sym][0].capitalize + ".")
    end
  end

  def find_orders(orders_items)
    orders = []
    orders_items.each do |item|
      # access via #first because it's inside of an ActiveRecord::Relation
      orders << Order.find(item.first.order_id)
    end

    # make sure there aren't duplicating orders
    orders.uniq { |order| order.id }
  end

  # make this work for orders and order items?
  def separate_by_status(orders)
    @pending, @paid, @completed, @canceled = [], [], [], []

    orders.each do |order|
      case order.status
      when "pending"
        @pending << order
      when "paid"
        @paid << order
      when "completed"
        @completed << order
      when "canceled"
        @canceled << order
      end
    end
  end

  def revenue(orders_items)
    orders_items.reduce(0) { |sum, n| sum + (n.first.product.price * n.first.quantity)}
  end
end
