class Wallet
  ACCT = STORE['cashier_acct']

  # Checks all open orders vs all incoming payments
  def self.scan
    # Get all ledger entries that transfer to our cashier account
    entries = []

    Graphene::API::RPC.instance.get_account_history(ACCT, 100000).each do |tx_data|
      tx = Tx.cache(tx_data)
      entry = tx.ledger_entry
      entries << entry if entry['to'] == ACCT && entry['from'] != ACCT
    end

    # For each tx, find the matching unpaid order, and check it pays in full
    open_orders = Order.where(:paid_at => nil).where('due_at > ?', 2.hours.ago)
    entries.each do |tx|
      order = open_orders.find{|o| tx['memo'].include?(o.pub_id)}
      next unless order
      next unless Amount.from_bts(tx['amount']).includes?(order.amount)
      order.update_attributes(:paid_at => DateTime.now, :trx_id => tx['trx_id'])
    end
  end



end
