module DisbursementRecordsHelper

  class LineItemWrapper
    attr_accessor :pt
    attr_accessor :dtl
    attr_accessor :pti_list
    def initialize(pt, dtl, pti_list)
      @pt = pt
      @dtl = dtl
      @pti_list = pti_list
    end
  end

  def DisbursementRecordsHelper.get_line_items(dr, payment_method, client)
    # Get the Disbursement Transaction Link records for the Disbursement Record identified by dr_id
    dtl_query = "SELECT Id, AmountSubjectToProcessingFee__c, " +
        "DiscountAmount__c, DonationAmount__c, BuyerOrderFee__c, BuyerFee__c, ItemPostFeeTotal__c, PatronTechFee__c, " +
        "BuyerPrice__c, ShippingFee__c, TransactionFee__c, TransactionTotal__c, OrganizationProcessingFee__c, " +
        # TODO - CreditCardTransactionFee__c not yet implemented in production
        #"ExchangeFee__c, CreditCardTransactionFee__c, PatronTrxPaymentTransaction__c " +
        "ExchangeFee__c, PatronTrxPaymentTransaction__c " +
        "FROM DisbursementTransactionLink__c " +
        "WHERE DisbursementRecord__c = '" + dr.Id + "'"
    if payment_method == "CC"
      dtl_query += " AND (PaymentMethod__c = 'Credit Card' or PaymentMethod__c = null)"
    else
      dtl_query += " AND (PaymentMethod__c != 'Credit Card' and PaymentMethod__c != null)"
    end
    dtl_query += " ORDER BY PatronTrxPaymentTransaction__r.PatronTrx__TransactionDate__c DESC"
    dtl_list = client.query(dtl_query)

    # Generate a comma separated list of PT IDs
    pt_ids = "("
    dtl_list.each do |dtl|
      pt_ids += "'" + dtl.PatronTrxPaymentTransaction__c + "',"
    end
    pt_ids = pt_ids.chop
    pt_ids += ")"

    # Get the PTs associated with these DTLs
    pt_query = "SELECT Id, Name, PatronTrx__FirstName__c, PatronTrx__LastName__c, " +
        "PatronTrx__TransactionDate__c, PatronTrx__OrderName__c, PatronTrx__Status__c " +
        "FROM PatronTrx__PaymentTransaction__c WHERE Id IN " + pt_ids
    pt_list = client.query(pt_query)

    # Put the PTs into a hash, keyed on PT.Id
    pt_hash = {}
    pt_list.each do |pt|
      pt_hash[pt.Id] = pt
    end

    # Get the child PTIs associated with the PTs. Normally, I'd do this with a child relationship query,
    # but the databasedotcom gem doesn't support child relationships.
    pti_query = "SELECT Id, PatronTrx__PaymentTransaction__c, PatronTrx__ItemName__c, " +
        "PatronTrx__ItemType__c, PatronTrx__Quantity__c " +
        "FROM PatronTrx__PaymentTransactionItem__c WHERE PatronTrx__PaymentTransaction__c IN " + pt_ids
    all_pti_list = client.query(pti_query)

    # Group the PTIs by their parent PT Id
    pti_hash = {}
    all_pti_list.each do |pti|
      pti_list = pti_hash[pti.PatronTrx__PaymentTransaction__c]
      if pti_list == nil
        pti_list = []
        pti_hash[pti.PatronTrx__PaymentTransaction__c] = pti_list
      end
      pti_list.append(pti)
    end

    # Build and return the list of LineItemWrapper
    line_items = []
    dtl_list.each do |dtl|
      line_item = DisbursementRecordsHelper::LineItemWrapper.new(
          pt_hash[dtl.PatronTrxPaymentTransaction__c], dtl, pti_hash[dtl.PatronTrxPaymentTransaction__c]
      )
      line_items.append(line_item)
    end
    return line_items
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
      @end_date = "TODO - END DATE"
      @currency_code= dr.CurrencyIsoCode
      @show_currency = (@currency_code != "USD")
      @has_chargebacks = false
      @has_partial_pmts = false
      @has_non_cc_txns = false
      @cc_txns = SummaryTotals.new()
      @non_cc_txns = SummaryTotals.new()
    end
  end

  def DisbursementRecordsHelper.get_summary_data(dr, client)

    summary_data = SummaryData.new(dr, client)

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
        "WHERE DisbursementRecord__c = '" + dr.Id +
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
        "WHERE DisbursementRecord__c = '" + dr.Id +
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
        "WHERE DisbursementRecord__c = '" + dr.Id +
        "' AND PatronTrxPaymentTransaction__r.PatronTrx__Status__c = 'Chargeback'")
    summary_data.has_chargebacks = ar[0].chargebackCnt > 0

    ar = client.query("SELECT COUNT(Id) ppCnt FROM DisbursementTransactionLink__c " +
        "WHERE DisbursementRecord__c = '" + dr.Id +
        "' AND PatronTrxPaymentTransaction__r.PatronTrx__Status__c = 'Partial Payment'")
    summary_data.has_partial_pmts = (ar[0].ppCnt > 0)

    return summary_data
  end
end