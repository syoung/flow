alias ra=rabbitmqadmin
alias rc=rabbitmqctl
alias rs=rabbitmq-server
alias rlq='rabbitmqctl -p rabbitvhost list_queues name messages message
_ready memory'
alias rlqq='rabbitmqctl list_queues name durable auto_delete arguments policy pid exclusive_consumer_pid exclusive_consumer_tag messages_ready messages consumers  memory slave_pids synchronised_slave_pids'
alias rle='rabbitmqctl list_exchanges name type durable auto_delete internal arguments policy'
alias rlog='tail -n 20 -f /flow/ext/exchange/rabbitmq/rabbitmq_server-3.8.4/var/log/rabbitmq/rabbit@a15e2efd1ca8.log'
