# frozen_string_literal: true

require "csv"

module SolidusMarketplace
  module Spree
    module Admin
      module ReportsControllerDecorator
        def self.prepended(base)
          base.before_action :add_marketplace_reports, only: [:index]
        end

        def earnings
          @supplier_earnings = get_supplier_earnings

          respond_to do |format|
            format.html
            format.csv { send_data(earnings_csv) }
          end
        end

        def earnings_csv
          header1 = ["Supplier Earnings"]
          header2 = ["Supplier", "Earnings", "Paypal Email"]

          CSV.generate do |csv|
            csv << header1
            csv << header2
            @supplier_earnings.each do |se|
              csv << ["#{se[:name]}",
                      "#{se[:earnings].to_html}",
                      "#{se[:paypal_email]}"]
            end
          end
        end

        def supplier_total_sales
          params[:q] = search_params

          @search = ::Spree::Order.complete.not_canceled.ransack(params[:q])
          @orders = @search.result

          @totals = {}
          supplier_sales_total_map = @orders.map(&:supplier_total_sales_map)
          grouped_suppliers_map = supplier_sales_total_map.flatten.group_by { |s| s[:name] }.values
          @grouped_sales = grouped_suppliers_map.map do |gs|
            h = {}
            h[:name] = nil
            h[:total_sales] = []
            gs.each do |s|
              h[:name] = s[:name] if h[:name].nil?
              h[:total_sales] << s[:total_sales]
            end
            h
          end

          @grouped_sales.each do |gs|
            gs[:total_sales] = gs[:total_sales].inject(::Spree::Money.new(0)) do |e, c|
              c + e
            end
          end

          respond_to do |format|
            format.html
            format.csv { send_data(supplier_total_sales_csv) }
          end
        end

        def supplier_total_sales_csv
          header1 = ["Supplier Total Sales"]
          header2 = ["Supplier", "Total Sales"]

          CSV.generate do |csv|
            csv << header1
            csv << header2
            @grouped_sales.each do |se|
              csv << ["#{se[:name]}",
                      "#{se[:total_sales].to_html}"]
            end
          end
        end

        private

        def add_marketplace_reports
          marketplace_reports.each do |report|
            ::Spree::Admin::ReportsController.add_available_report!(report)
          end
        end

        def marketplace_reports
          [:earnings, :supplier_total_sales]
        end

        def get_supplier_earnings
          grouped_supplier_earnings.each do |se|
            se[:earnings] = se[:earnings].inject(::Spree::Money.new(0)) do |e, c|
              c + e
            end
          end
        end

        def grouped_supplier_earnings
          params[:q] = search_params

          @search = ::Spree::Order.complete.not_canceled.ransack(params[:q])
          @orders = @search.result

          supplier_earnings_map = @orders.map(&:supplier_earnings_map)
          grouped_suppliers_map = supplier_earnings_map.flatten.group_by { |s| s[:name] }.values
          grouped_earnings = grouped_suppliers_map.map do |gs|
            h = {}
            h[:name] = nil
            h[:paypal_email] = nil
            h[:earnings] = []
            gs.each do |s|
              h[:name] = s[:name] if h[:name].nil?
              h[:paypal_email] = s[:paypal_email] if h[:paypal_email].nil?
              h[:earnings] << s[:earnings]
            end
            h
          end

          grouped_earnings
        end

        if defined?(SolidusReports::Engine)
          ::Spree::Admin::ReportsController.prepend self
        end
      end
    end
  end
end
