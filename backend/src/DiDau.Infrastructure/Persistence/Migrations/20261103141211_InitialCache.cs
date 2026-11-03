using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiDau.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "nearby_cache",
                columns: table => new
                {
                    key = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_nearby_cache", x => x.key);
                });

            migrationBuilder.CreateTable(
                name: "place_cache",
                columns: table => new
                {
                    place_id = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    fetched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_place_cache", x => x.place_id);
                });

            migrationBuilder.CreateTable(
                name: "tour_cache",
                columns: table => new
                {
                    key = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tour_cache", x => x.key);
                });

            migrationBuilder.CreateTable(
                name: "wiki_cache",
                columns: table => new
                {
                    key = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_wiki_cache", x => x.key);
                });

            migrationBuilder.CreateIndex(
                name: "IX_nearby_cache_expires_at",
                table: "nearby_cache",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "IX_place_cache_expires_at",
                table: "place_cache",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "IX_tour_cache_expires_at",
                table: "tour_cache",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "IX_wiki_cache_expires_at",
                table: "wiki_cache",
                column: "expires_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "nearby_cache");

            migrationBuilder.DropTable(
                name: "place_cache");

            migrationBuilder.DropTable(
                name: "tour_cache");

            migrationBuilder.DropTable(
                name: "wiki_cache");
        }
    }
}
