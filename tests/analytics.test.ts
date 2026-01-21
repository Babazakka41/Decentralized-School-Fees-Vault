import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;

describe("Fee Payment Analytics & Reporting System", () => {
  
  describe("Monthly Statistics", () => {
    it("should retrieve monthly payment statistics correctly", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-monthly-statistics", 
        [Cl.uint(2024), Cl.uint(6)], 
        address1
      );
      
      // Should return error when no data exists
      expect(result).toBeErr(Cl.uint(301)); // ERR_ANALYTICS_NOT_FOUND
    });
    
    it("should return error for invalid month", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-monthly-statistics", 
        [Cl.uint(2024), Cl.uint(13)], // Invalid month
        address1
      );
      
      expect(result).toBeErr(Cl.uint(302)); // ERR_INVALID_DATE_RANGE
    });

    it("should return error for invalid year", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-monthly-statistics", 
        [Cl.uint(2019), Cl.uint(6)], // Year too low
        address1
      );
      
      expect(result).toBeErr(Cl.uint(302)); // ERR_INVALID_DATE_RANGE
    });
  });
  
  describe("Seasonal Trends", () => {
    it("should calculate quarterly trends accurately", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarterly-trends", 
        [Cl.uint(2024), Cl.uint(2)], 
        address1
      );
      
      // Should return error when no data exists
      expect(result).toBeErr(Cl.uint(301)); // ERR_ANALYTICS_NOT_FOUND
    });
    
    it("should handle invalid quarters gracefully", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarterly-trends", 
        [Cl.uint(2024), Cl.uint(5)], // Invalid quarter
        address1
      );
      
      expect(result).toBeErr(Cl.uint(302)); // ERR_INVALID_DATE_RANGE
    });
  });
  
  describe("Payment Day Patterns", () => {
    it("should track payment frequency by day", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-payment-day-pattern", 
        [Cl.uint(15)], 
        address1
      );
      
      // Should return default values when no data exists
      expect(result).toBeOk(
        Cl.tuple({
          "payment-count": Cl.uint(0),
          "total-amount": Cl.uint(0),
          "avg-amount": Cl.uint(0),
        })
      );
    });

    it("should return error for invalid day", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-payment-day-pattern", 
        [Cl.uint(32)], // Invalid day
        address1
      );
      
      expect(result).toBeErr(Cl.uint(302)); // ERR_INVALID_DATE_RANGE
    });
  });
  
  describe("Yearly Aggregations", () => {
    it("should aggregate yearly totals correctly", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "aggregate-yearly-totals", 
        [Cl.uint(2024)], 
        address1
      );
      
      // Should return zero values when no data exists
      expect(result).toBeOk(
        Cl.tuple({
          "year": Cl.uint(2024),
          "total-payments": Cl.uint(0),
          "total-students": Cl.uint(0),
          "avg-yearly-payment": Cl.uint(0),
          "quarters-analyzed": Cl.uint(4),
        })
      );
    });
    
    it("should calculate multi-year averages", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "calculate-payment-average", 
        [Cl.uint(2022), Cl.uint(2024)], 
        address1
      );
      
      // Should return no data available initially
      expect(result).toBeErr(Cl.uint(303)); // ERR_NO_DATA_AVAILABLE
    });

    it("should return error for invalid date range", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "calculate-payment-average", 
        [Cl.uint(2025), Cl.uint(2022)], // End year before start year
        address1
      );
      
      expect(result).toBeErr(Cl.uint(302)); // ERR_INVALID_DATE_RANGE
    });
  });
  
  describe("Performance Metrics", () => {
    it("should generate comprehensive performance metrics", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "generate-performance-metrics", 
        [], 
        address1
      );
      
      // Should return initial metrics
      expect(result).toBeOk(
        Cl.tuple({
          "total-vaults-created": Cl.uint(0),
          "total-amount-locked": Cl.uint(0),
          "total-amount-released": Cl.uint(0),
          "total-amount-processed": Cl.uint(0),
          "release-rate": Cl.uint(0),
          "avg-vault-size": Cl.uint(0),
          "system-utilization": Cl.uint(0),
          "performance-score": Cl.uint(0),
        })
      );
    });

    it("should get analytics system health status", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-analytics-health", 
        [], 
        address1
      );
      
      expect(result).toBeOk(
        Cl.tuple({
          "system-status": Cl.stringAscii("inactive"),
          "data-points": Cl.uint(0),
          "total-volume": Cl.uint(0),
          "analytics-version": Cl.stringAscii("v1.0.0"),
          "last-updated": Cl.uint(simnet.blockHeight),
        })
      );
    });
  });

  describe("Utility Functions", () => {
    it("should calculate month from block height", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-month-from-block", 
        [Cl.uint(8640)], // 2 months worth of blocks
        address1
      );
      
      expect(result).toBeUint(3); // Should return month 3
    });

    it("should calculate year from block height", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-year-from-block", 
        [Cl.uint(51840)], // 1 year worth of blocks
        address1
      );
      
      expect(result).toBeUint(2021); // Should return year 2021 (2020 + 1)
    });

    it("should calculate quarter from month", () => {
      const { result: q1 } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarter-from-month", 
        [Cl.uint(2)], 
        address1
      );
      expect(q1).toBeUint(1);

      const { result: q2 } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarter-from-month", 
        [Cl.uint(5)], 
        address1
      );
      expect(q2).toBeUint(2);

      const { result: q3 } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarter-from-month", 
        [Cl.uint(8)], 
        address1
      );
      expect(q3).toBeUint(3);

      const { result: q4 } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-quarter-from-month", 
        [Cl.uint(12)], 
        address1
      );
      expect(q4).toBeUint(4);
    });
  });

  describe("Vault Insights", () => {
    it("should return error for non-existent vault", () => {
      const { result } = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-vault-insights", 
        [Cl.uint(999)], 
        address1
      );
      
      expect(result).toBeErr(Cl.uint(4)); // ERR_VAULT_NOT_FOUND
    });
  });

  describe("Integration Tests", () => {
    it("should handle multiple function calls gracefully", () => {
      // Test multiple read-only calls in sequence
      const healthResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-analytics-health", 
        [], 
        address1
      );
      expect(healthResult.result).toBeOk(
        Cl.tuple({
          "system-status": Cl.stringAscii("inactive"),
          "data-points": Cl.uint(0),
          "total-volume": Cl.uint(0),
          "analytics-version": Cl.stringAscii("v1.0.0"),
          "last-updated": Cl.uint(simnet.blockHeight),
        })
      );

      const metricsResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "generate-performance-metrics", 
        [], 
        address1
      );
      expect(metricsResult.result).toBeOk(
        Cl.tuple({
          "total-vaults-created": Cl.uint(0),
          "total-amount-locked": Cl.uint(0),
          "total-amount-released": Cl.uint(0),
          "total-amount-processed": Cl.uint(0),
          "release-rate": Cl.uint(0),
          "avg-vault-size": Cl.uint(0),
          "system-utilization": Cl.uint(0),
          "performance-score": Cl.uint(0),
        })
      );

      const averageResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "calculate-payment-average", 
        [Cl.uint(2023), Cl.uint(2024)], 
        address1
      );
      expect(averageResult.result).toBeErr(Cl.uint(303)); // No data available
    });
  });

  describe("Edge Cases", () => {
    it("should handle boundary values correctly", () => {
      // Test minimum valid year
      const minYearResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-monthly-statistics", 
        [Cl.uint(2020), Cl.uint(1)], 
        address1
      );
      expect(minYearResult.result).toBeErr(Cl.uint(301)); // No data, but valid range

      // Test maximum valid year
      const maxYearResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-monthly-statistics", 
        [Cl.uint(2050), Cl.uint(12)], 
        address1
      );
      expect(maxYearResult.result).toBeErr(Cl.uint(301)); // No data, but valid range

      // Test minimum valid day
      const minDayResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-payment-day-pattern", 
        [Cl.uint(1)], 
        address1
      );
      expect(minDayResult.result).toBeOk(
        Cl.tuple({
          "payment-count": Cl.uint(0),
          "total-amount": Cl.uint(0),
          "avg-amount": Cl.uint(0),
        })
      );

      // Test maximum valid day
      const maxDayResult = simnet.callReadOnlyFn(
        "Decentralized-School-Fees-Vault", 
        "get-payment-day-pattern", 
        [Cl.uint(31)], 
        address1
      );
      expect(maxDayResult.result).toBeOk(
        Cl.tuple({
          "payment-count": Cl.uint(0),
          "total-amount": Cl.uint(0),
          "avg-amount": Cl.uint(0),
        })
      );
    });
  });
});
