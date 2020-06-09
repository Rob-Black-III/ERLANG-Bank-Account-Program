%%%-------------------------------------------------------------------
%%% @author Rob Black rdb5063@rit.edu
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 22. Nov 2019 3:13 PM
%%%-------------------------------------------------------------------
-module(prog4).
-author("rdb5063@rit.edu").

%% API
-export([start/0,bank/0,spawnNClients/1,bankReceiveLoop/2,client/1,clientSend/3,clientReceive/0,random/2]).

random(LowerBound, UpperBound) when LowerBound >= 0 -> rand:uniform(UpperBound - LowerBound) + LowerBound;
random(LowerBound, UpperBound) when LowerBound < 0 -> rand:uniform(UpperBound) - rand:uniform(-1 * LowerBound).

start() -> spawn(prog4,bank,[]).

bank() ->
  %%% GENERATE RANDOM START BALANCE AND NUMBER OF CLIENTS
  Balance = random(2000,3000),
  NumCustomers = random(2,10),

  %%% SPAWN CLIENTS
  %%%spawnNClients(NumCustomers),
  spawnNClients(NumCustomers),
  io:format("[BANK] ~p Created. ~n", [self()]),
  io:format("[BANK] ~p Balance: ~p ~n", [self(),Balance]),
  io:format("[BANK] ~p NumCustomers: ~p ~n", [self(),NumCustomers]),

  %%% LISTEN FOR CLIENTS
  bankReceiveLoop(Balance, NumCustomers).

bankReceiveLoop(Balance, NumCustomers) ->
  if
    NumCustomers =< 0 ->
      io:format("[BANK] ~p All Customers Completed Transactions. Final Balance: ~p ~n", [self(),Balance]),
      exit("[BANK] Bank Closed After All Customers Completed.");
    true ->
      ok
  end,

  receive
    goodbye ->
      %%%io:format("Bank Received Goodbye ~n"),
      bankReceiveLoop(Balance, NumCustomers-1);
    {ClientId, "balance"} ->
      io:format("[BANK] ~p Client ~p requesting balance: ~p ~n", [self(),ClientId,Balance]),
      ClientId ! {Balance},
      bankReceiveLoop(Balance, NumCustomers);
    {ClientId, Number} ->
      %%%io:format("Bank Received Number(Transactions) ~n"),
      if
        Balance + Number > 0 ->
          NewBalance = Balance + Number,
          %%%io:format("Bank Assigning New Balance From Transaction~n"),
          if
            Number > 0 ->
              io:format("[BANK] ~p Client ~p depositing ~p ~n", [self(),ClientId,Number]),
              ClientId ! {Number, NewBalance,yes};
            true ->
              io:format("[BANK] ~p Client ~p withdrawing ~p ~n", [self(),ClientId,-1 * Number]),
              ClientId ! {Number, NewBalance,yes}
          end,
          bankReceiveLoop(NewBalance, NumCustomers);
        true ->
          %%%io:format("Bank Invalid Transaction ~n"),
          ClientId ! {Number, Balance,no},
          bankReceiveLoop(Balance, NumCustomers)
      end
  end.

spawnNClients(0) ->
  [];

spawnNClients(Number) ->
  spawn(prog4,client,[self()]),
  %%%io:format("Spawned Client: ~n"),
  spawnNClients(Number-1).

client(BankPID) ->
  NumTransactions = random(10,20),
  Transactions = [random(-100,100) || _ <- lists:seq(1, NumTransactions)],
  %%%io:format("     NumTransactions: ~p ~n",[NumTransactions]),
  %%%io:format("     Transactions: ~p ~n",[Transactions]),
  clientSend(BankPID,Transactions,0).

clientSend(BankPID,TransactionList, SendCounter) ->
  %%% SPLIT LIST, ASSIGN TAIL TO NEW TRANSACTIONS, TAKE HEAD AS CURRENT
  {CurrentTransactionAsList, TailTransactionList} = lists:split(1,TransactionList),
  CurrentTransaction = lists:nth(1,CurrentTransactionAsList),

  %%% SEND TRANSACTION TO BANK
  if
    SendCounter == 5  ->
      %%%io:format("     Requesting Balance. ~n"),
      BankPID ! {self(),"balance"},
      clientReceive(),
      %%%io:format("     Sending Transaction. ~n"),
      BankPID ! {self(),CurrentTransaction},
      clientReceive();
    true ->
      %%%io:format("     Sending Transaction. ~n"),
      BankPID ! {self(),CurrentTransaction},
      clientReceive()
  end,

  %%% RECURSIVE CALL TO NEXT TRANSACTION
  if
    TailTransactionList == []->
      BankPID ! goodbye,
      io:format("[CLIENT] ~p is out of transactions. Goodbye. ~n", [self()]);
    true ->
      %%%io:format("     Recursive Call For Next Transaction ~n"),
      if
        SendCounter == 5 ->
          clientSend(BankPID,TailTransactionList, 1);
        true ->
          clientSend(BankPID,TailTransactionList, SendCounter + 1)
      end
  end.

sleep(Time) ->
  receive
    after Time ->
    true
  end.

clientReceive() ->
  receive
    {Amount, Balance, Flag} ->
      if
        Amount > 0 ->
          io:format("[CLIENT] ~p made a deposit of amount ~p. Bank balance is ~p. Transaction Completed?: ~p ~n", [self(),Amount,Balance,Flag]),
          sleep(random(500,1500));
        true ->
          io:format("[CLIENT] ~p made a withdrawl of amount ~p. Bank balance is ~p. Transaction Completed?: ~p ~n", [self(),-1 * Amount,Balance,Flag]),
          sleep(random(500,1500))
      end;
    {Balance} ->
      io:format("[CLIENT] ~p Requested Current Bank Balance: ~p ~n", [self(),Balance]),
      sleep(random(500,1500))
  end.

