import XCTest
@testable import LiteLLMUsageBarCore

final class LiteLLMModelsTests: XCTestCase {
    func testDecodesDailyActivityEnvelope() throws {
        let json = """
        {
          "results": [
            {
              "date": "2026-06-01",
              "spend": 2.15,
              "prompt_tokens": 1000,
              "completion_tokens": 250,
              "total_tokens": 1250,
              "request_count": 4
            },
            {
              "date": "2026-06-02",
              "total_spend": 3.85,
              "num_requests": 7
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(DailyActivityResponse.self, from: json)

        XCTAssertEqual(response.rows.count, 2)
        XCTAssertEqual(response.rows[0].day, "2026-06-01")
        XCTAssertEqual(response.rows[0].spend, Decimal(string: "2.15")!)
        XCTAssertEqual(response.rows[0].promptTokens, 1000)
        XCTAssertEqual(response.rows[0].completionTokens, 250)
        XCTAssertEqual(response.rows[0].totalTokens, 1250)
        XCTAssertEqual(response.rows[0].requestCount, 4)
        XCTAssertEqual(response.rows[1].spend, Decimal(string: "3.85")!)
        XCTAssertEqual(response.rows[1].requestCount, 7)
    }

    func testDecodesDailyActivityArray() throws {
        let json = """
        [
          { "date": "2026-06-03", "spend": 1.25, "request_count": 2 }
        ]
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(DailyActivityResponse.self, from: json)

        XCTAssertEqual(response.rows.count, 1)
        XCTAssertEqual(response.rows[0].day, "2026-06-03")
        XCTAssertEqual(response.rows[0].spend, Decimal(string: "1.25")!)
        XCTAssertEqual(response.rows[0].requestCount, 2)
    }

    func testDecodesDailyActivityNestedMetrics() throws {
        let json = """
        {
          "metadata": {
            "page": 1
          },
          "results": [
            {
              "date": "2026-06-03",
              "metrics": {
                "spend": 4.75,
                "prompt_tokens": 100,
                "completion_tokens": 40,
                "total_tokens": 140,
                "api_requests": 3
              },
              "breakdown": {
                "models": {}
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(DailyActivityResponse.self, from: json)

        XCTAssertEqual(response.rows.count, 1)
        XCTAssertEqual(response.rows[0].day, "2026-06-03")
        XCTAssertEqual(response.rows[0].spend, Decimal(string: "4.75")!)
        XCTAssertEqual(response.rows[0].promptTokens, 100)
        XCTAssertEqual(response.rows[0].completionTokens, 40)
        XCTAssertEqual(response.rows[0].totalTokens, 140)
        XCTAssertEqual(response.rows[0].requestCount, 3)
    }

    func testDecodesUserInfoBudgetFromUserThenKey() throws {
        let json = """
        {
          "user_info": {
            "max_budget": 100,
            "spend": 42.1,
            "budget_reset_at": "2026-07-01T00:00:00Z",
            "currency": "USD"
          },
          "key_info": {
            "max_budget": 75
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(UserInfoResponse.self, from: json)

        XCTAssertEqual(response.preferredBudget, Decimal(100))
        XCTAssertEqual(response.userSpend, Decimal(string: "42.1")!)
        XCTAssertEqual(response.currency, "USD")
        XCTAssertEqual(ISO8601DateFormatter().string(from: response.budgetResetAt!), "2026-07-01T00:00:00Z")
    }

    func testDecodesUserInfoBudgetFromKeyWhenUserBudgetMissing() throws {
        let json = """
        {
          "user_info": {
            "spend": 12.4
          },
          "key_info": {
            "budget": 25
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(UserInfoResponse.self, from: json)

        XCTAssertEqual(response.preferredBudget, Decimal(25))
        XCTAssertEqual(response.userSpend, Decimal(string: "12.4")!)
        XCTAssertNil(response.budgetResetAt)
    }
}
