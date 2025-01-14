# frozen_string_literal: true

require "helper"

# ruby -w -Itest test/cluster_commands_on_server_test.rb
# @see https://redis.io/commands#server
class TestClusterCommandsOnServer < Minitest::Test
  include Helper::Cluster

  def test_bgrewriteaof
    assert_equal 'Background append only file rewriting started', redis.bgrewriteaof
  end

  def test_bgsave
    redis_cluster_mock(bgsave: ->(*_) { '+OK' }) do |redis|
      assert_equal 'OK', redis.bgsave
    end

    err_msg = 'ERR An AOF log rewriting in progress: '\
              "can't BGSAVE right now. "\
              'Use BGSAVE SCHEDULE in order to schedule a BGSAVE whenever possible.'

    redis_cluster_mock(bgsave: ->(*_) { "-Error #{err_msg}" }) do |redis|
      assert_raises(Redis::Cluster::CommandErrorCollection, 'Command error replied on any node') do
        redis.bgsave
      end
    end
  end

  def test_client_kill
    redis_cluster_mock(client: ->(*_) { '-Error ERR No such client' }) do |redis|
      assert_raises(Redis::CommandError, 'ERR No such client') do
        redis.client(:kill, '127.0.0.1:6379')
      end
    end

    redis_cluster_mock(client: ->(*_) { '+OK' }) do |redis|
      assert_equal 'OK', redis.client(:kill, '127.0.0.1:6379')
    end
  end

  def test_client_list
    a_client_info = redis.client(:list).first
    assert_instance_of Hash, a_client_info
    assert_includes a_client_info, 'addr'
  end

  def test_client_getname
    redis.client(:setname, 'my-client-01')
    assert_equal 'my-client-01', redis.client(:getname)
  end

  def test_client_pause
    assert_equal 'OK', redis.client(:pause, 0)
  end

  def test_client_reply
    assert_equal 'OK', redis.client(:reply, 'ON')
  end

  def test_client_setname
    assert_equal 'OK', redis.client(:setname, 'my-client-01')
  end

  def test_command
    assert_instance_of Array, redis.command
  end

  def test_command_count
    assert_equal true, (redis.command(:count) > 0)
  end

  def test_command_getkeys
    assert_equal %w[a c e], redis.command(:getkeys, :mset, 'a', 'b', 'c', 'd', 'e', 'f')
  end

  def test_command_info
    expected = [
      ['get', 2, %w[readonly fast], 1, 1, 1],
      ['set', -3, %w[write denyoom], 1, 1, 1],
    ]
    assert_equal(expected, redis.command(:info, :get, :set).map { |c| c.first(6) })
  end

  def test_config_get
    assert_equal ['hash-max-ziplist-entries'], redis.config(:get, 'hash-max-ziplist-entrie*').keys.sort
  end

  def test_config_rewrite
    redis_cluster_mock(config: ->(*_) { '-Error ERR Rewriting config file: Permission denied' }) do |redis|
      assert_raises(Redis::Cluster::CommandErrorCollection, 'Command error replied on any node') do
        redis.config(:rewrite)
      end
    end

    redis_cluster_mock(config: ->(*_) { '+OK' }) do |redis|
      assert_equal 'OK', redis.config(:rewrite)
    end
  end

  def test_config_set
    assert_equal 'OK', redis.config(:set, 'hash-max-ziplist-entries', 512)
  end

  def test_config_resetstat
    assert_equal 'OK', redis.config(:resetstat)
  end

  def test_config_db_size
    10.times { |i| redis.set("key#{i}", 1) }
    assert_equal 10, redis.dbsize
  end

  def test_debug_object
    # DEBUG OBJECT is a debugging command that should not be used by clients.
  end

  def test_debug_segfault
    # DEBUG SEGFAULT performs an invalid memory access that crashes Redis.
    # It is used to simulate bugs during the development.
  end

  def test_flushall
    assert_equal 'OK', redis.flushall
  end

  def test_flushdb
    assert_equal 'OK', redis.flushdb
  end

  def test_info
    assert_equal({ 'cluster_enabled' => '1' }, redis.info(:cluster))
  end

  def test_lastsave
    assert_instance_of Array, redis.lastsave
  end

  def test_memory_doctor
    assert_instance_of String, redis.memory(:doctor)
  end

  def test_memory_help
    assert_instance_of Array, redis.memory(:help)
  end

  def test_memory_malloc_stats
    assert_instance_of String, redis.memory('malloc-stats')
  end

  def test_memory_purge
    assert_equal 'OK', redis.memory(:purge)
  end

  def test_memory_stats
    assert_instance_of Array, redis.memory(:stats)
  end

  def test_memory_usage
    redis.set('key1', 'Hello World')
    assert_operator redis.memory(:usage, 'key1'), :>, 0
  end

  def test_monitor
    # Add MONITOR command test
  end

  def test_role
    assert_equal %w[master master master], redis.role.map(&:first)
  end

  def test_save
    assert_equal 'OK', redis.save
  end

  def test_shutdown
    assert_raises(Redis::Cluster::OrchestrationCommandNotSupported, 'SHUTDOWN command should be...') do
      redis.shutdown
    end
  end

  def test_slaveof
    assert_raises(Redis::CommandError, 'ERR SLAVEOF not allowed in cluster mode.') do
      redis.slaveof(:no, :one)
    end
  end

  def test_slowlog
    assert_instance_of Array, redis.slowlog(:get, 1)
  end

  def test_sync
    # Internal command used for replication
  end

  def test_time
    assert_instance_of Array, redis.time
  end
end
