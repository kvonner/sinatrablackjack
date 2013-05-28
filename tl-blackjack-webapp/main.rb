require 'rubygems'
require 'sinatra'

set :sessions, true

#Constants

BLACKJACK_AMOUNT = 21
DEALER_HIT_AMOUNT = 17
ACE_VALUE = 11
FACE_VALUE = 10
INITIAL_POT = 500

helpers do
	def calculate_total(cards)
		arr = cards.map{|element| element[1]}

		total = 0
		arr.each do |a|
			if a == "A"
				total += ACE_VALUE
			else
				total += a.to_i == 0 ? FACE_VALUE : a.to_i
			end
		end

    #correct for aces
    arr.select{|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= FACE_VALUE
    end

    total 
	end

  def card_image(card)
    suit = case card[0]
	    when 'H' then 'hearts'
	    when 'C' then 'clubs'
	    when 'S' then 'spades'
	    when 'D' then 'diamonds'
	  end

	  value = card[1]
	  if ['J', 'Q', 'K', 'A'].include?(value)
	  	value = case card[1]
		  	when 'J' then 'jack'
		  	when 'Q' then 'queen'
		  	when 'K' then 'king'
		  	when 'A' then 'ace'
		  end
	  end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
  	@show_hit_or_stay_buttons = false
  	session[:player_pot] = session[:player_pot] + session[:player_bet].to_i
  	@winner = "<strong> #{session[:player_name]} wins! </strong> #{msg}"
  	@play_again = true
  end	

  def loser!(msg)
  	@show_hit_or_stay_buttons = false
  	session[:player_pot] = session[:player_pot] - session[:player_bet].to_i
  	@loser = "<strong> #{session[:player_name]} loses! </strong> #{msg}"
  	@play_again = true
  end

  def tie!(msg)
  	@show_hit_or_stay_buttons = false
  	@winner = "<strong> #{session[:player_name]} and the dealer tie! </strong> #{msg}"
  	@play_again = true
  end		

end

before do
	@show_hit_or_stay_buttons = true
end

get '/' do
	if session[:player_name]
		redirect '/game'
	else
		redirect '/new_player'
	end
end

get '/new_player' do
	session[:player_pot] = INITIAL_POT
	erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
	  @error = "Please enter a player name"
	  halt erb(:new_player)
	end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
	session[:bet_amount] = nil
  erb :bet
end

post '/bet' do
	if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
	  @error = "Please place a bet"
	  halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot].to_i
  	@error = "Bet amount cannot be greater than your total pot ($#{session[:player_pot]})"
  	halt erb(:bet)
  else
  	session[:player_bet] = params[:bet_amount].to_i
  	redirect '/game'
	end
end

get '/game' do
  session[:turn] = session[:player_name]

  # deck and put it in sessions
  suits = [ "H", "D", "C", "S" ]
  values =[ "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" ]
  session[:deck] = suits.product(values).shuffle!

  # deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  
  if player_total == BLACKJACK_AMOUNT
  	winner!("#{session[:player_name]} hits blackjack!")
	end

	dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
  	loser!("Dealer hits blackjack!")
  end

  #player turn

	erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  
  if player_total == BLACKJACK_AMOUNT
  	winner!("#{session[:player_name]} hits blackjack!")
	end

  if calculate_total(session[:player_cards]) > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} busted at #{player_total}")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay"
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
	session[:turn] = "dealer"

  @show_hit_or_stay_buttons = false
  
  #decision tree
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
  	loser!("Dealer hits blackjack!")
  elsif dealer_total > BLACKJACK_AMOUNT
  	winner!("Dealer busted with #{dealer_total}")
  elsif dealer_total >= DEALER_HIT_AMOUNT
  	#dealer stays
  	redirect '/game/compare'
  else
  	#dealer hits
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
	@show_hit_or_stay_buttons = false
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
  	loser!("#{session[:player_name]} stayed at #{player_total}, and dealer stayed at #{dealer_total}")
  elsif player_total > dealer_total
  	winner!("#{session[:player_name]} stayed at #{player_total}, and dealer stayed at #{dealer_total}")
  else
  	tie!("both #{session[:player_name]} and the dealer stayed at #{player_total}")
  end

 erb :game, layout: false
end

get '/game_over' do
	erb :game_over
end
  
