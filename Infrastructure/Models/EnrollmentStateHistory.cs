using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EnrollmentStateHistory
{
    public long Id { get; set; }

    public int EnrollmentId { get; set; }

    public int? FromStateId { get; set; }

    public int ToStateId { get; set; }

    public DateTime ChangedAt { get; set; }

    public int? ChangedBy { get; set; }

    public virtual User? ChangedByNavigation { get; set; }

    public virtual Enrollment Enrollment { get; set; } = null!;

    public virtual EnrollmentState? FromState { get; set; }

    public virtual EnrollmentState ToState { get; set; } = null!;
}
