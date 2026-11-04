using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiDau.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddOsmCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "osm_cache",
                columns: table => new
                {
                    key = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_osm_cache", x => x.key);
                });

            migrationBuilder.CreateIndex(
                name: "IX_osm_cache_expires_at",
                table: "osm_cache",
                column: "expires_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "osm_cache");
        }
    }
}
