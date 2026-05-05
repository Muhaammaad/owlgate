defmodule OwlGate.Connectors.DispatcherTest do
  use ExUnit.Case, async: true

  alias OwlGate.Connectors.Dispatcher

  test "provision returns external reference from mock provider" do
    assert {:ok, result} = Dispatcher.provision(%{"request_id" => 123})
    assert String.starts_with?(result.external_ref, "mock-access-")
  end

  test "revoke returns external reference from mock provider" do
    assert {:ok, result} = Dispatcher.revoke(%{"grant_id" => 456})
    assert String.starts_with?(result.external_ref, "mock-revoked-")
  end
end
