module DisbursementRecordsHelper

  class DisbursementReportDescriptor
    attr_accessor :disbursement_record
    attr_accessor :cc_items
    attr_accessor :non_cc_items
    attr_accessor :summary_data
    def initialize(dr_id, client)
      # Get the Disbursement Record object
      @disbursement_record = client.query("SELECT Id, Name, OrganizationName__c, EndDate__c, " +
          "PatronManagerOpportunity__c, PatronManagerOpportunity__r.PatronManager_Account_Org_ID__c, " +
          "CurrencyIsoCode, CreatedDate, CreatedById, CreatedBy.Name " +
          "FROM DisbursementRecord__c WHERE Id = '" + dr_id + "'")[0]

      # Get the Credit Card line items
      @cc_items = get_line_items("CC", client)

      # Get the non CC line items
      @non_cc_items = get_line_items("", client)

      # Get the summary data
      @summary_data = get_summary_data(client)
    end

    # This method gets the line items for the specified payment method returns them as a collection of LineItemWrapper objects
    def get_line_items(payment_method, client)
      # Generate a query to get the Disbursement Transaction Link records for the Disbursement Record identified by dr_id
      dtl_query = "SELECT Id, AmountSubjectToProcessingFee__c, " +
          "DiscountAmount__c, DonationAmount__c, BuyerOrderFee__c, BuyerFee__c, " +
          "ItemPostFeeTotal__c, PatronTechFee__c, BuyerPrice__c, ShippingFee__c, " +
          "TransactionFee__c, TransactionTotal__c, OrganizationProcessingFee__c, " +
          # TODO - CreditCardTransactionFee__c not yet implemented in production
          #"ExchangeFee__c, CreditCardTransactionFee__c, PatronTrxPaymentTransaction__c " +
          "ExchangeFee__c, PatronTrxPaymentTransaction__c " +
          "FROM DisbursementTransactionLink__c " +
          "WHERE DisbursementRecord__c = '" + @disbursement_record.Id + "' "
      if payment_method == "CC"
        dtl_query += "AND (PaymentMethod__c = 'Credit Card' OR PaymentMethod__c = null) "
      else
        dtl_query += "AND (PaymentMethod__c != 'Credit Card' AND PaymentMethod__c != null) "
      end
      dtl_query += "ORDER BY PatronTrxPaymentTransaction__r.PatronTrx__TransactionDate__c DESC"

      # Execute the query and loop to make sure we get all records in the case where there are more than 2000 transactions
      dtl_collection = client.query(dtl_query)
      dtl_list = dtl_collection.dup.to_a
      while dtl_collection.next_page_url
        dtl_collection = dtl_collection.next_page
        dtl_list += dtl_collection
      end

      # We're done if there are no DTL records
      return if dtl_list.size == 0

      # Generate a query to get the PTs (and child PTIs) associated with these DTLs
      pt_query = "SELECT Id, Name, PatronTrx__FirstName__c, PatronTrx__LastName__c, " +
          "PatronTrx__TransactionDate__c, PatronTrx__OrderName__c, " +
          "PatronTrx__Status__c, PatronTrx__OrganizationId__c, " +
          "(SELECT Id, PatronTrx__ItemName__c, PatronTrx__ItemType__c, PatronTrx__Quantity__c " +
          "FROM PatronTrx__PaymentTransactionItem__r) " +
          "FROM PatronTrx__PaymentTransaction__c " +
          "WHERE Id IN (SELECT PatronTrxPaymentTransaction__c FROM DisbursementTransactionLink__c " +
          "WHERE DisbursementRecord__c = '" + @disbursement_record.Id + "' "
      if payment_method == "CC"
        pt_query += "AND (PaymentMethod__c = 'Credit Card' OR PaymentMethod__c = null))"
      else
        pt_query += "AND (PaymentMethod__c != 'Credit Card' AND PaymentMethod__c != null))"
      end

      # Execute the query and loop to make sure we get all records in the case where there are more than 2000 transactions
      pt_collection = client.query(pt_query)
      pt_list = pt_collection.dup.to_a
      while pt_collection.next_page_url
        pt_collection = pt_collection.next_page
        pt_list += pt_collection
      end

      # Put the PTs into a hash, keyed on PT.Id
      pt_hash = Hash[pt_list.map {|pt| [pt.Id, pt]}]

      # Build and return the list of LineItemWrapper objects
      dtl_list.collect {|dtl| DisbursementRecordsHelper::LineItemWrapper.new(pt_hash[dtl.PatronTrxPaymentTransaction__c], dtl)}
    end

    # This method returns summaries of the CC and non-CC transaction totals.
    def get_summary_data(client)

      summary_data = SummaryData.new(@disbursement_record, client)

      # Get Credit Card totals
      ar = client.query("SELECT SUM(AmountSubjectToProcessingFee__c) amtSubjToProcFee, " +
                            "SUM(DiscountAmount__c) discAmt, SUM(DonationAmount__c) donationAmt, SUM(BuyerOrderFee__c) buyOrderFee, " +
                            "SUM(BuyerFee__c) buyLineItemFee, SUM(ItemPostFeeTotal__c) itmPostFeeTotal, SUM(PatronTechFee__c) pTechFee, " +
                            "SUM(BuyerPrice__c) buyerPrice, SUM(ShippingFee__c) deliveryFee, SUM(TransactionFee__c) transFee, " +
                            "SUM(TransactionTotal__c) transTotal, SUM(OrganizationProcessingFee__c) orgProcFee " +
=begin  TODO Add this back in when CC Transaction Fee is available on production
        "SUM(TransactionTotal__c) transTotal, SUM(OrganizationProcessingFee__c) orgProcFee, " +
        "SUM(ExchangeFee__c) exchangeFee, SUM(CreditCardTransactionFee__c) ccFee " +
=end
                        "FROM DisbursementTransactionLink__c " +
                            "WHERE DisbursementRecord__c = '" + @disbursement_record.Id +
                            "' AND (PaymentMethod__c = 'Credit Card' OR PaymentMethod__c = null)")

      # Since we're doing SUM operations there will only be one row
      summary_data.cc_txns.amt_subj_to_proc_fee = ar[0].amtSubjToProcFee if ar[0].amtSubjToProcFee
      summary_data.cc_txns.discount_amt = ar[0].discAmt if ar[0].discAmt
      summary_data.cc_txns.donation_amt = ar[0].donationAmt if ar[0].donationAmt
      summary_data.cc_txns.buyer_line_item_fee = ar[0].buyerLineItemFee if ar[0].buyerLineItemFee
      summary_data.cc_txns.buyer_order_fee = ar[0].buyOrderFee if ar[0].buyOrderFee
      summary_data.cc_txns.item_post_fee_total = ar[0].itmPostFeeTotal if ar[0].itmPostFeeTotal
      summary_data.cc_txns.org_proc_fee = ar[0].orgProcFee if ar[0].orgProcFee
      summary_data.cc_txns.ptech_fee = ar[0].pTechFee if ar[0].pTechFee
      summary_data.cc_txns.buyer_price = ar[0].buyerPrice if ar[0].buyerPrice
      summary_data.cc_txns.delivery_fee = ar[0].deliveryFee if ar[0].deliveryFee
      summary_data.cc_txns.exch_fee = ar[0].exchangeFee if ar[0].exchangeFee
      summary_data.cc_txns.txn_fee = ar[0].transFee if ar[0].transFee
      summary_data.cc_txns.txn_total = ar[0].transTotal if ar[0].transTotal
=begin TODO Add this back in when CC Transaction Fee is available on production
    summary_data.cc_txns.cc_txn_fee = ar.ccFee if ar.ccFee
=end
      summary_data.cc_txns.net_total = summary_data.cc_txns.amt_subj_to_proc_fee + summary_data.cc_txns.org_proc_fee

      # Get the non-CC totals
      ar = client.query("SELECT SUM(AmountSubjectToProcessingFee__c) amtSubjToProcFee, " +
                            "SUM(DiscountAmount__c) discAmt, SUM(DonationAmount__c) donationAmt, SUM(BuyerOrderFee__c) buyOrderFee, " +
                            "SUM(BuyerFee__c) buyLineItemFee, SUM(ItemPostFeeTotal__c) itmPostFeeTotal, SUM(PatronTechFee__c) pTechFee, " +
                            "SUM(BuyerPrice__c) buyerPrice, SUM(ShippingFee__c) deliveryFee, SUM(TransactionFee__c) transFee, " +
                            "SUM(TransactionTotal__c) transTotal, SUM(OrganizationProcessingFee__c) orgProcFee, " +
                            "SUM(ExchangeFee__c) exchangeFee " +
                            "FROM DisbursementTransactionLink__c " +
                            "WHERE DisbursementRecord__c = '" + @disbursement_record.Id +
                            "' AND (PaymentMethod__c != 'Credit Card' AND PaymentMethod__c != null)")

      # Since we're only doing SUM operations, there will only be one row
      summary_data.non_cc_txns.amt_subj_to_proc_fee = ar[0].amtSubjToProcFee if ar[0].amtSubjToProcFee
      summary_data.non_cc_txns.discount_amt = ar[0].discAmt if ar[0].discAmt
      summary_data.non_cc_txns.donation_amt = ar[0].donationAmt if ar[0].donationAmt
      summary_data.non_cc_txns.buyer_line_item_fee = ar[0].buyerLineItemFee if ar[0].buyerLineItemFee
      summary_data.non_cc_txns.buyer_order_fee = ar[0].buyOrderFee if ar[0].buyOrderFee
      summary_data.non_cc_txns.item_post_fee_total = ar[0].itmPostFeeTotal if ar[0].itmPostFeeTotal
      summary_data.non_cc_txns.org_proc_fee = ar[0].orgProcFee if ar[0].orgProcFee
      summary_data.non_cc_txns.ptech_fee = ar[0].pTechFee if ar[0].pTechFee
      summary_data.non_cc_txns.buyer_price = ar[0].buyerPrice if ar[0].buyerPrice
      summary_data.non_cc_txns.delivery_fee = ar[0].deliveryFee if ar[0].deliveryFee
      summary_data.non_cc_txns.exch_fee = ar[0].exchangeFee if ar[0].exchangeFee
      summary_data.non_cc_txns.txn_fee = ar[0].transFee if ar[0].transFee
      summary_data.non_cc_txns.txn_total = ar[0].transTotal if ar[0].transTotal

      summary_data.has_non_cc_txns = (summary_data.non_cc_txns.txn_total != 0)

      # Get the count of chargebacks and partial payments
      ar = client.query("SELECT COUNT(Id) chargebackCnt FROM DisbursementTransactionLink__c " +
                            "WHERE DisbursementRecord__c = '" + @disbursement_record.Id +
                            "' AND PatronTrxPaymentTransaction__r.PatronTrx__Status__c = 'Chargeback'")
      summary_data.has_chargebacks = ar[0].chargebackCnt > 0

      ar = client.query("SELECT COUNT(Id) ppCnt FROM DisbursementTransactionLink__c " +
                            "WHERE DisbursementRecord__c = '" + @disbursement_record.Id +
                            "' AND PatronTrxPaymentTransaction__r.PatronTrx__Status__c = 'Partial Payment'")
      summary_data.has_partial_pmts = (ar[0].ppCnt > 0)

      return summary_data
    end
  end


  class LineItemWrapper
    attr_accessor :pt
    attr_accessor :dtl
    def initialize(pt, dtl)
      @pt = pt
      @dtl = dtl
    end
  end

  class SummaryTotals
    attr_accessor :amt_subj_to_proc_fee
    attr_accessor :discount_amt
    attr_accessor :donation_amt
    attr_accessor :buyer_line_item_fee
    attr_accessor :buyer_order_fee
    attr_accessor :item_post_fee_total
    attr_accessor :org_proc_fee
    attr_accessor :ptech_fee
    attr_accessor :buyer_price
    attr_accessor :delivery_fee
    attr_accessor :exch_fee
    attr_accessor :txn_fee
    attr_accessor :txn_total
    attr_accessor :net_total
    attr_accessor :cc_txn_fee
    def initialize()
      @amt_subj_to_proc_fee = 0
      @discount_amt = 0
      @donation_amt = 0
      @buyer_line_item_fee = 0
      @buyer_order_fee = 0
      @item_post_fee_total = 0
      @org_proc_fee = 0
      @ptech_fee = 0
      @buyer_price = 0
      @delivery_fee = 0
      @exch_fee = 0
      @txn_fee = 0
      @txn_total = 0
      @net_total = 0
      @cc_txn_fee = 0
    end
  end

  class SummaryData
    attr_accessor :dis_rec_id
    attr_accessor :dis_rec_name
    attr_accessor :org_name
    attr_accessor :created_date
    attr_accessor :end_date
    attr_accessor :currency_code
    attr_accessor :show_currency
    attr_accessor :has_chargebacks
    attr_accessor :has_partial_pmts
    attr_accessor :has_non_cc_txns
    attr_accessor :cc_txns
    attr_accessor :non_cc_txns
    def initialize(dr, client)
      @dis_rec_id = dr.Id
      @dis_rec_name = dr.Name
      @org_name = dr.OrganizationName__c
      @created_date = Time.parse(dr.CreatedDate)
      @end_date = Time.parse(dr.EndDate__c) - 1.second
      @currency_code= dr.CurrencyIsoCode
      @show_currency = (@currency_code != "USD")
      @has_chargebacks = false
      @has_partial_pmts = false
      @has_non_cc_txns = false
      @cc_txns = SummaryTotals.new()
      @non_cc_txns = SummaryTotals.new()
    end
  end
end
