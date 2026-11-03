using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiDau.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemovePersistentPlaceCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM tour_cache");
            migrationBuilder.DropTable(
                name: "place_cache");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "place_cache",
                columns: table => new
                {
                    place_id = table.Column<string>(type: "text", nullable: false),
                    fetched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_place_cache", x => x.place_id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_place_cache_expires_at",
                table: "place_cache",
                column: "expires_at");
        }
    }
}

