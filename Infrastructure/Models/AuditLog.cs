using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class AuditLog
{
    public int Id { get; set; }

    public string? EventType { get; set; }

    public string EventData { get; set; } = null!;

    public DateTime? CreatedAt { get; set; }
}
